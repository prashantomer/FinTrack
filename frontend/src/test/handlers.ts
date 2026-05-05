import { http, HttpResponse } from 'msw'

const pendingBatch = {
  id: 1,
  import_type: 'investments',
  status: 'pending',
  file_name: 'test.csv',
  total_rows: 0,
  processed_rows: 0,
  failed_rows: 0,
  import_version: 1,
  progress_pct: 0,
  import_records: [],
  created_at: '2024-01-01T00:00:00Z',
}

const completedBatch = {
  ...pendingBatch,
  status: 'completed',
  progress_pct: 100,
}

export const handlers = [
  http.get('/api/v1/imports', () =>
    HttpResponse.json({
      success: true,
      code: 200,
      request_id: 'test',
      data: [],
      meta_data: { total: 0, page: 1, page_size: 20 },
    }),
  ),

  http.post('/api/v1/imports', () =>
    HttpResponse.json({
      success: true,
      code: 201,
      request_id: 'test',
      data: pendingBatch,
      meta_data: {},
    }),
  ),

  http.get('/api/v1/imports/1', () =>
    HttpResponse.json({
      success: true,
      code: 200,
      request_id: 'test',
      data: completedBatch,
      meta_data: {},
    }),
  ),

  http.get('/api/v1/platform-accounts', () =>
    HttpResponse.json({
      success: true,
      code: 200,
      request_id: 'test',
      data: [],
      meta_data: {},
    }),
  ),

  http.get('/api/v1/accounts', () =>
    HttpResponse.json({
      success: true,
      code: 200,
      request_id: 'test',
      data: [],
      meta_data: {},
    }),
  ),
]
