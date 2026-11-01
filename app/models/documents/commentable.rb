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

    # Search the content outline for a block whose text contains the selection.
    # The outline is the same text the agent sees, so what anchors here is what
    # the agent read from read_document.
    def locate_selected_text(selected_text)
      block_texts = {}
      collect_outline_texts = lambda do |entries|
        entries.each do |entry|
          block_texts[entry[:block_id]] = entry[:text] if entry[:text].present?
          collect_outline_texts.call(entry[:children].to_a)
        end
      end
      collect_outline_texts.call(content_outline)

      block_id, block_text = block_texts.find { |_id, text| text.include?(selected_text) }
      return nil unless block_id

      start_offset = block_text.index(selected_text)
      { start_block_id: block_id, end_block_id: block_id, start_offset:, end_offset: start_offset + selected_text.length }
    end

    def current_version_comments
      return Comment.none if current_version_id.blank?

      comments.where(document_version_id: current_version_id)
    end
  end
end
