# frozen_string_literal: true

class WorkspacesController < ApplicationController
  def update
    if params[:switch_token].present?
      target_user = User.authenticate_by_token(params[:switch_token].to_s.strip)
      if target_user
        cookies.encrypted[:user_token] = { value: target_user.token, expires: 1.year.from_now }
        session[:user_token] = target_user.token
        redirect_back_or_to root_path, notice: "Switched to workspace: #{target_user.name}"
      else
        redirect_back_or_to root_path, alert: "Workspace token not found"
      end
    elsif params[:user].present? && params[:user][:name].present?
      current_user.update(name: params[:user][:name])
      redirect_back_or_to root_path, notice: "Workspace updated"
    else
      redirect_back_or_to root_path
    end
  end

  def create
    new_user = User.create!(name: params[:name].presence || "New Workspace")
    cookies.encrypted[:user_token] = { value: new_user.token, expires: 1.year.from_now }
    session[:user_token] = new_user.token
    redirect_back_or_to root_path, notice: "Created and switched to new workspace"
  end
end
