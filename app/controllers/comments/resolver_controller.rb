class Comments::ResolverController < ApplicationController
  include CommentPayloadable

  before_action :set_document
  before_action :set_comment

  def update
    begin
      @comment = @document.set_comment_resolved!(@comment.id, resolved: !@comment.is_resolved)
    rescue Documents::Commentable::UnresolvableComment => e
      render plain: e.message, status: :unprocessable_entity
      return
    end

    set_comment_payload
  end

  private

  def set_document
    @document = current_user.documents.find_by(id: params[:document_id]) || Document.find(params[:document_id])
  end

  def set_comment
    @comment = @document.comments.find(params[:comment_id])
  end
end
