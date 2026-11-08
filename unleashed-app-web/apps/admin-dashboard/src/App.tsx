import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './lib/AuthProvider'
import { ToastProvider } from './components/Toast'
import { ProtectedRoute } from './components/ProtectedRoute'
import { Layout } from './components/Layout'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { ProductsPage } from './pages/ProductsPage'
import { ProductFormPage } from './pages/ProductFormPage'
import { ProductDetailPage } from './pages/ProductDetailPage'
import { InventoryPage } from './pages/InventoryPage'
import { OrdersPage } from './pages/OrdersPage'
import { OrderDetailPage } from './pages/OrderDetailPage'
import { CustomersPage } from './pages/CustomersPage'
import { MessagesPage } from './pages/MessagesPage'
import { NotificationsPage } from './pages/NotificationsPage'
import { ReviewsPage } from './pages/ReviewsPage'
import { AnnouncementsPage } from './pages/AnnouncementsPage'
import { ReportsPage } from './pages/ReportsPage'
import { SettingsPage } from './pages/SettingsPage'
import { NotFoundPage } from './pages/NotFoundPage'

export default function App() {
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route index element={<DashboardPage />} />
                <Route path="products" element={<ProductsPage />} />
                <Route path="products/new" element={<ProductFormPage mode="create" />} />
                <Route path="products/:id" element={<ProductDetailPage />} />
                <Route path="products/:id/edit" element={<ProductFormPage mode="edit" />} />
                <Route path="inventory" element={<InventoryPage />} />
                <Route path="orders" element={<OrdersPage />} />
                <Route path="orders/:id" element={<OrderDetailPage />} />
                <Route path="customers" element={<CustomersPage />} />
                <Route path="messages" element={<MessagesPage />} />
                <Route path="notifications" element={<NotificationsPage />} />
                <Route path="reviews" element={<ReviewsPage />} />
                <Route path="announcements" element={<AnnouncementsPage />} />
                <Route path="reports" element={<ReportsPage />} />
                <Route path="settings" element={<SettingsPage />} />
                <Route path="*" element={<NotFoundPage />} />
              </Route>
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  )
}
