class PoolTournamentsController < ApplicationController
  def create
    @pool = current_user.pools.find(params[:pool_id])
    tournament = Tournament.find(params[:tournament_id])
    @pool.pool_tournaments.find_or_create_by!(tournament: tournament)
    redirect_to @pool, notice: "Tournament added."
  end

  def destroy
    pt = PoolTournament.find(params[:id])
    @pool = current_user.pools.find(pt.pool_id)
    pt.destroy!
    redirect_to @pool, notice: "Tournament removed from pool."
  end
end
