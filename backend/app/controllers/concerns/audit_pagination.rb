module AuditPagination
  extend ActiveSupport::Concern

  AUDITS_DEFAULT_LIMIT = 50
  AUDITS_MAX_LIMIT     = 200

  # Cursor-paginates an `Audited::Audit` relation in created_at DESC order.
  # Returns `[page_rows, next_cursor]` where `next_cursor` is the id to send
  # as `?before=` on the next request, or nil when the page is the last.
  #
  # Cursor semantics: rows are sorted (created_at desc, id desc) — the id
  # is a tiebreaker for audits written in the same millisecond, which
  # happens often during bulk imports. The cursor is the LAST row's id;
  # the next page asks for rows whose id is strictly less than it.
  def paginate_audits(scope)
    limit  = params[:limit].to_i
    limit  = AUDITS_DEFAULT_LIMIT if limit <= 0
    limit  = AUDITS_MAX_LIMIT     if limit > AUDITS_MAX_LIMIT

    scope = scope.order(created_at: :desc, id: :desc)
    scope = scope.where("audits.id < ?", params[:before].to_i) if params[:before].present?

    # Fetch limit+1 so we can tell whether another page exists without a
    # second COUNT(*).
    page = scope.limit(limit + 1).to_a
    has_more   = page.size > limit
    page       = page.first(limit)
    next_cursor = has_more ? page.last.id : nil

    [ page, next_cursor ]
  end
end
