import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import {
  executeCleanup, previewCleanup,
  type CleanupConfig, type CleanupExecuteResponse, type CleanupPreviewResponse,
} from '@/api/cleanup'

export function usePreviewCleanup() {
  return useMutation<CleanupPreviewResponse, Error, CleanupConfig>({
    mutationFn: previewCleanup,
    onError:    () => toast.error('Failed to load preview'),
  })
}

export function useExecuteCleanup() {
  const qc = useQueryClient()
  return useMutation<CleanupExecuteResponse, Error, CleanupConfig>({
    mutationFn: executeCleanup,
    onSuccess:  () => {
      // The cleanup may have touched every domain — bust everything at the
      // root TanStack Query cache so subsequent navigation reloads fresh.
      qc.invalidateQueries()
      toast.success('Cleanup complete')
    },
    onError: (err) => toast.error(err.message || 'Cleanup failed'),
  })
}
