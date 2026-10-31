class Comments::VersionResolverController < ApplicationController
  include CommentPayloadable

  before_action :set_document
  before_action :set_document_version, if: -> { params[:document_version_id].present? }

  def update
    begin
      if @document_version
        @document.set_version_comments_resolved!(@document_version.id, resolved: resolved?)
      else
        @document.set_all_archived_comments_resolved!(resolved: resolved?)
      end
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

  def set_document_version
    @document_version = @document.document_versions.find(params[:document_version_id])
  end

  def resolved?
    ActiveModel::Type::Boolean.new.cast(params[:resolved])
  end
end