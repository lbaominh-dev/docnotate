class CommentsController < ApplicationController
  include CommentPayloadable

  before_action :set_document

  def create
    @comment = @document.comments.build(comment_params)

    if @comment.save
      set_comment_payload
      render :create
    else
      @create_error = @comment.errors.full_messages.to_sentence
      set_comment_payload
      render :create, status: :unprocessable_entity
    end
  end

  def destroy
    @comment = @document.comments.find(params[:id])

    if @comment.destroy
      set_comment_payload
      render :destroy
    else
      @destroy_error = @comment.errors.full_messages.to_sentence
      set_comment_payload
      render :destroy, status: :unprocessable_entity
    end
  end

  def update
    @comment = @document.comments.find(params[:id])

    if @comment.update(comment_params)
      set_comment_payload
      render :update
    else
      @edit_error = @comment.errors.full_messages.to_sentence
      set_comment_payload
      render :update, status: :unprocessable_entity
    end
  end

  private

  def set_document
    @document = current_user.documents.find_by(id: params[:document_id]) || Document.find(params[:document_id])
  end

  def comment_params
    params.permit(
      :content,
      :start_block_id,
      :end_block_id,
      :start_offset,
      :end_offset,
      :selected_text,
      :prefix_text,
      :postfix_text
    )
  end
end
