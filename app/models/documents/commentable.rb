module Documents
  module Commentable
    extend ActiveSupport::Concern

    class Error < StandardError; end
    class UnresolvableComment < Error; end

    # Same permit-shape as CommentsController#comment_params — the anchor fields
    # both the UI's selection and agent tools work with.
    ANCHOR_FIELDS = %i[start_block_id end_block_id start_offset end_offset
                       selected_text prefix_text postfix_text].freeze

    # Latest inline comments, show on document highlight
    def highlight_comments
      current_version_comments
        .order(:created_at)
        .map { |c| c.slice(:id, :content, :selected_text, :start_block_id, :end_block_id,
                           :start_offset, :end_offset, :is_resolved, :created_at)
                    .merge(content_html: c.rendered_content) }
    end

    # Model-level comment writes so tools and controllers share one rule set.
    # All of them raise on failure; tools rescue and turn the message into a
    # result-level error response.
    def create_comment!(attributes = {})
      comment = comments.build(content: attributes[:content], document_version: current_version)
      comment.assign_attributes(anchor_attributes(attributes, comment))
      # raise before save!: a save-time validation run clears manually added
      # errors, which would silently lose the anchor-not-found message.
      raise ActiveRecord::RecordInvalid.new(comment) if comment.errors.any?

      comment.save!
      comment
    end

    def update_comment!(id, content)
      comment = comments.find(id)
      comment.update!(content: content)
      comment
    end

    def destroy_comment!(id)
      comment = comments.find(id)
      comment.destroy!
      comment
    end

    def set_comment_resolved!(id, resolved:)
      comment = comments.find(id)
      if comment.document_version_id == current_version_id
        raise UnresolvableComment, "Current-version comments cannot be resolved"
      end

      comment.update!(is_resolved: resolved)
      comment
    end

    # Bulk-resolve every comment pinned to one document version (the "previous
    # comments" inbox action). Same current-version guard as the per-comment
    # case, so the resolver rule exists in exactly one place.
    def set_version_comments_resolved!(version_id, resolved:)
      document_versions.find(version_id).tap do |version|
        if version.id == current_version_id
          raise UnresolvableComment, "Current-version comments cannot be resolved"
        end

        version.resolve_all_comments!(resolved)
      end
    end

    def set_all_archived_comments_resolved!(resolved: true)
      comments.where.not(document_version_id: current_version_id).update_all(is_resolved: resolved)
    end

    # Comments belong to previous document version, show on a separate section as archived comments
    def archived_comments
      comments
        .where.not(document_version_id: current_version_id)
        .joins(:document_version)
        .merge(DocumentVersion.order(created_at: :desc))
        .order("comments.created_at ASC")
    end

    # Group archived comments by their document version, preserving version order
    def archived_comments_by_version
      archived_comments.group_by(&:document_version)
    end

    # Serialized payload for archived comments used by the "Previous comments"
    # section and the comment source JSON.
    def archived_comments_payload
      archived_comments.map do |comment|
        comment.slice(:id, :content, :selected_text, :created_at, :is_resolved)
               .merge(version: comment.document_version.version,
                      content_html: comment.rendered_content)
      end
    end

    # Full comment source consumed by Stimulus: current inline highlights
    # plus archived comments for the inbox / previous-comments section.
    def comment_payload
      {
        current: highlight_comments,
        archived: archived_comments_payload
      }
    end

    # comment_payload filtered by resolution state, for agent surfaces that
    # want only the feedback still open. Shapes stay identical to the UI's so
    # both surfaces read the same contract.
    def comments_payload(status: "all")
      payload = comment_payload
      return payload if status == "all"

      resolved = status == "resolved"
      payload.transform_values { |list| list.select { |comment| comment[:is_resolved] == resolved } }
    end

    private

    # Fill in the block span from selected_text when the caller gives no block
    # ids: agents "comment on a point" using text from the outline without
    # knowing our offset scheme. An explicit span always wins, mirroring the UI
    # which sends both selected_text and the span together.
    def anchor_attributes(attributes, comment)
      anchor = attributes.slice(*ANCHOR_FIELDS)
      return anchor if anchor[:start_block_id].present?
      return anchor unless anchor[:selected_text].present?

      span = locate_selected_text(anchor[:selected_text])
      if span.nil?
        comment.errors.add(:selected_text, "not found in the current version of the document")
      else
        anchor.merge!(span)
      end
      anchor
    end

    # Search the document's content outline and leaf blocks for the selection.
    # Supports matching within a single block or across multiple consecutive blocks,
    # normalizing line breaks, whitespace, and markdown prefixes (bullets/numbers).
    # The outline is the same text the agent sees via read_document.
    def locate_selected_text(selected_text)
      target = selected_text.to_s.strip
      return nil if target.blank?

      blocks = commentable_leaf_blocks_with_text
      return nil if blocks.empty?

      # Build composite text across blocks with mapping to block_id and dom_offset
      doc_human_text = +""
      doc_to_block = []

      blocks.each_with_index do |b, block_idx|
        if block_idx > 0
          2.times do
            doc_to_block << nil
            doc_human_text << "\n"
          end
        end

        b[:human_text].each_char.with_index do |ch, h_idx|
          doc_to_block << { block_index: block_idx, block_id: b[:block_id], dom_offset: b[:human_to_dom][h_idx] }
          doc_human_text << ch
        end
      end
      doc_to_block << nil

      match_range = find_selected_text_range(doc_human_text, target)
      return nil unless match_range

      start_char, end_char = match_range
      start_char += 1 while start_char < doc_to_block.length && doc_to_block[start_char].nil?
      end_char -= 1 while end_char >= 0 && doc_to_block[end_char].nil?

      return nil if start_char > end_char || doc_to_block[start_char].nil? || doc_to_block[end_char].nil?

      start_info = doc_to_block[start_char]
      end_info = doc_to_block[end_char]
      end_block = blocks[end_info[:block_index]]

      {
        start_block_id: start_info[:block_id],
        end_block_id: end_info[:block_id],
        start_offset: start_info[:dom_offset],
        end_offset: [ end_info[:dom_offset] + 1, end_block[:dom_text].length ].min
      }
    end

    def find_selected_text_range(doc_text, target)
      # 1. Exact match
      if (idx = doc_text.index(target))
        return [ idx, idx + target.length - 1 ]
      end

      # 2. Normalized whitespace match
      words = target.split(/\s+/)
      if words.any?
        pattern = Regexp.new(words.map { |w| Regexp.escape(w) }.join('\s+'), Regexp::MULTILINE)
        if (m = doc_text.match(pattern))
          return [ m.begin(0), m.end(0) - 1 ]
        end
      end

      # 3. Match without markdown prefixes (#, list numbers, bullets)
      cleaned_lines = target.lines.map { |l| l.sub(/^\s*(#+\s+|\d+\.\s+|[-*+]\s+)/, "") }
      cleaned_words = cleaned_lines.join.split(/\s+/)
      if cleaned_words.any? && cleaned_words != words
        pattern = Regexp.new(cleaned_words.map { |w| Regexp.escape(w) }.join('\s+'), Regexp::MULTILINE)
        if (m = doc_text.match(pattern))
          return [ m.begin(0), m.end(0) - 1 ]
        end
      end

      nil
    end

    def commentable_leaf_blocks_with_text
      leaf_nodes = []
      walk = lambda do |node|
        has_child_blocks = node.children.any? { |c| c.node_id.present? }
        if node.node_id.present? && !has_child_blocks
          leaf_nodes << node
        else
          node.children.each { |c| walk.call(c) }
        end
      end

      root_node_tree.each { |r| walk.call(r) }
      leaf_nodes.map { |n| extract_block_text_with_mapping(n) }
    end

    def extract_block_text_with_mapping(node)
      dom_text = +""
      human_text = +""
      human_to_dom = []

      walk_text = lambda do |n|
        if n.node_type == "softbreak" || n.node_type == "linebreak"
          human_to_dom << dom_text.length
          human_text << (n.node_type == "linebreak" ? "\n" : " ")
        elsif n.children.empty? && n.content.present?
          n.content.to_s.each_char do |ch|
            human_to_dom << dom_text.length
            dom_text << ch
            human_text << ch
          end
        elsif n.node_type == "text" || n.node_type == "code"
          n.content.to_s.each_char do |ch|
            human_to_dom << dom_text.length
            dom_text << ch
            human_text << ch
          end
        else
          n.children.each { |child| walk_text.call(child) unless child.node_id.present? }
        end
      end

      walk_text.call(node)
      human_to_dom << dom_text.length
      { block_id: node.node_id, dom_text: dom_text, human_text: human_text, human_to_dom: human_to_dom }
    end


    def current_version_comments
      return Comment.none if current_version_id.blank?

      comments.where(document_version_id: current_version_id)
    end
  end
end
