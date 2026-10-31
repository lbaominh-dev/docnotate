class DocumentContentsController < ApplicationController
  before_action :set_document
  before_action :sandbox_response

  def show
    case @document.current_version&.content
    when HtmlContent
      render html: HtmlFrameDocument.new(@document.current_version.content.annotated_html).to_html.html_safe, layout: false
    else
      head :not_found
    end
  end

  def asset
    file = @document.asset_file(params[:path])

    if file
      send_file file, disposition: "inline"
    else
      head :not_found
    end
  end

  private

  def set_document
    @document = current_user.documents.find_by(id: params[:document_id]) || Document.find(params[:document_id])
  end

  # Served from the app origin, so a sibling script or SVG must not run with the app's privileges.
  def sandbox_response
    response.headers["Content-Security-Policy"] = "sandbox allow-scripts"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end
end
