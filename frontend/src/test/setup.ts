import '@testing-library/jest-dom'
import { server } from './server'

// Set a fake auth token so the Axios interceptor doesn't redirect to /login
localStorage.setItem('token', 'test-token')

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
