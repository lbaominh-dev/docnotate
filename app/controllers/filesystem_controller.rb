# frozen_string_literal: true

class FilesystemController < ApplicationController
  before_action :ensure_local_mode!
  def show
    @path = params[:path].presence || Dir.home
    @frame_id = params[:frame_id].presence || "filesystem_tree"
    @active_file_path = params[:active_file_path].presence
    @result = Filesystem::DirectoryScanner.scan(@path)

    respond_to do |format|
      format.html do
        render partial: "filesystem/tree", locals: {
          result: @result,
          frame_id: @frame_id,
          active_file_path: @active_file_path
        }
      end
      format.json do
        render json: {
          current_path: @result.current_path,
          parent_path: @result.parent_path,
          breadcrumbs: @result.breadcrumbs,
          entries: @result.entries.map(&:to_h)
        }
      end
    end
  rescue Filesystem::DirectoryScanner::ScanError => e
    respond_to do |format|
      format.html do
        render partial: "filesystem/error", locals: { message: e.message, path: @path, frame_id: @frame_id }, status: :unprocessable_entity
      end
      format.json do
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end

  def nodes
    @path = params[:path].presence || Dir.home
    @active_file_path = params[:active_file_path].presence
    @result = Filesystem::DirectoryScanner.scan(@path)

    respond_to do |format|
      format.html do
        render partial: "filesystem/nodes", locals: {
          entries: @result.entries,
          active_file_path: @active_file_path
        }
      end
      format.json do
        render json: { entries: @result.entries.map(&:to_h) }
      end
    end
  rescue Filesystem::DirectoryScanner::ScanError => e
    respond_to do |format|
      format.html do
        render partial: "filesystem/error", locals: { message: e.message, path: @path }, status: :unprocessable_entity
      end
      format.json do
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end

  private

  def ensure_local_mode!
    head :forbidden if Docnotate.cloud?
  end
end
