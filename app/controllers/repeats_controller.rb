class RepeatsController < ApplicationController
  def index
    respond_to do |format|
      format.json { render_json Repeat.all }
    end
  end
end
