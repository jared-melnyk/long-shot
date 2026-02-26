class TournamentResultsController < ApplicationController
  def create
    @tournament = Tournament.find(params[:tournament_id])
    @result = @tournament.tournament_results.build(tournament_result_params)
    if @result.save
      redirect_to @tournament, notice: "Result added."
    else
      redirect_to @tournament, alert: @result.errors.full_messages.join(", ")
    end
  end

  def destroy
    @result = TournamentResult.find(params[:id])
    @tournament = @result.tournament
    @result.destroy!
    redirect_to @tournament, notice: "Result removed."
  end

  private

  def tournament_result_params
    params.require(:tournament_result).permit(:golfer_id, :prize_money, :position)
  end
end