import { Link } from 'react-router-dom'
import { EmptyState } from '../components/ui'
import { Icon } from '../components/Icon'

export function NotFoundPage() {
  return (
    <div className="page-stack">
      <section className="panel not-found">
        <EmptyState
          icon="search"
          title="Page not found"
          description="That route does not exist in the admin dashboard."
          action={
            <Link to="/" className="button button-primary">
              <Icon name="dashboard" size={16} />
              Back to overview
            </Link>
          }
        />
      </section>
    </div>
  )
}
