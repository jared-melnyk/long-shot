class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.order(starts_at: :asc)
  end

  def show
    @tournament = Tournament.find(params[:id])
  end

  def new
    @tournament = Tournament.new
  end

  def create
    @tournament = Tournament.new(tournament_params)
    if @tournament.save
      redirect_to tournaments_path, notice: "Tournament added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def tournament_params
    params.require(:tournament).permit(:name, :starts_at, :ends_at, :external_id)
  end
end