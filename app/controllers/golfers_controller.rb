class GolfersController < ApplicationController
  def index
    @golfers = Golfer.order(:name)
  end

  def new
    @golfer = Golfer.new
  end

  def create
    @golfer = Golfer.new(golfer_params)
    if @golfer.save
      redirect_to golfers_path, notice: "Golfer added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def golfer_params
    params.require(:golfer).permit(:name, :external_id)
  end
end
