# frozen_string_literal: true

class AuthenticatedMcpApp
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    token = request.params["token"].presence ||
            request.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip

    user = User.authenticate_by_token(token)

    if Docnotate.local? && token.blank?
      user ||= User.first || User.create!(name: "Local Workspace")
    end

    unless user
      body = {
        error: "Unauthorized: Missing or invalid token parameter (?token=<your_workspace_token>). You can find or create your workspace token in the DocNotate Web UI."
      }.to_json

      return [
        401,
        {
          "content-type" => "application/json",
          "content-length" => body.bytesize.to_s
        },
        [ body ]
      ]
    end

    Current.set(user: user) do
      @app.call(env)
    end
  end
end
