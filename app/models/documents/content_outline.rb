module Documents
  module ContentOutline
    extend ActiveSupport::Concern

    # Block-level outline of the current version, flattened to what an agent
    # needs: one entry per commentable block. `block_id` is the stored node_id,
    # the same id inline comments anchor to — agents reuse it later when they
    # comment on a block without touching the tree internals.
    #
    # Markdown keeps text in leaf text nodes (node_id: nil) under a block;
    # HTML keeps inline text on the block node itself, so text collection
    # combines both shapes.
    def content_outline
      return [] unless current_version

      build_outline(root_node_tree)
    end

    private

    def build_outline(nodes)
      nodes.flat_map do |node|
        entry = block_outline(node)
        if entry
          [ entry ]
        elsif node.node_id.blank?
          # Wrapper nodes (the markdown "document" root) own no block id:
          # drop the wrapper, lift its block children into this level.
          build_outline(node.children)
        else
          []
        end
      end
    end

    def block_outline(node)
      return nil unless node.node_id

      entry = { block_id: node.node_id, type: node.node_type }
      entry[:level] = node.heading_level if node.heading_level.present?
      entry[:text] = collect_text(node).strip
      children = build_outline(node.children)
      entry[:children] = children if children.any?
      entry
    end

    def collect_text(node)
      case node.node_type
      when "softbreak"
        " "
      when "linebreak"
        "\n"
      else
        own = node.content.to_s
        child_text = node.children.filter_map { |child| collect_text(child) unless child.node_id }.join
        own + child_text
      end
    end
  end
end
