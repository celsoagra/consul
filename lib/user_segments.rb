class UserSegments

  def self.segments
    %w(all_users
       administrators
       proposal_authors
       investment_authors
       feasible_and_undecided_investment_authors
       selected_investment_authors
       winner_investment_authors
       not_supported_on_current_budget) + geozones
  end

  def self.all_users
    User.active
  end

  def self.administrators
    all_users.administrators
  end

  def self.proposal_authors
    author_ids(Proposal.not_archived.not_retired.pluck(:author_id).uniq)
  end

  def self.investment_authors
    author_ids(current_budget_investments.pluck(:author_id).uniq)
  end

  def self.feasible_and_undecided_investment_authors
    unfeasible_and_finished_condition = "feasibility = 'unfeasible' and valuation_finished = true"
    investments = current_budget_investments.where.not(unfeasible_and_finished_condition)
    author_ids(investments.pluck(:author_id).uniq)
  end

  def self.selected_investment_authors
    author_ids(current_budget_investments.selected.pluck(:author_id).uniq)
  end

  def self.winner_investment_authors
    author_ids(current_budget_investments.winners.pluck(:author_id).uniq)
  end

  def self.not_supported_on_current_budget
    author_ids(
      User.where(
                  'id NOT IN (SELECT DISTINCT(voter_id) FROM votes'\
                  ' WHERE votable_type = ? AND votes.votable_id IN (?))',
                  'Budget::Investment',
                  current_budget_investments.pluck(:id)
                )
    )
  end

  def self.geozones
    geozones_available? ? geozone_names : []
  end

  def self.geozones_available?
    ActiveRecord::Base.connection.table_exists?('geozones')
  end

  def self.geozone_names
    Geozone.pluck(:name).map(&:parameterize).map(&:underscore).sort - ["city"]
  end

  def self.generate_geozone_segments
    Geozone.all.each do |geozone|
      method_name = geozone.name.parameterize.underscore
      self.define_singleton_method(:"#{method_name}") do
        all_users.where(geozone: geozone)
      end
    end
  end

  if self.geozones_available?
    self.generate_geozone_segments
  end

  def self.user_segment_emails(users_segment)
    UserSegments.send(users_segment).newsletter.pluck(:email).compact
  end

  private

  def self.current_budget_investments
    Budget.current.investments
  end

  def self.author_ids(author_ids)
    all_users.where(id: author_ids)
  end

end
