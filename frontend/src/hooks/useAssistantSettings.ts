import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  getAssistantSetting,
  testAssistantSetting,
  updateAssistantSetting,
  type AssistantSettingUpdate,
} from '@/api/assistant'

const KEY = ['assistant', 'setting'] as const

export function useAssistantSettings() {
  const qc = useQueryClient()
  const query = useQuery({ queryKey: KEY, queryFn: getAssistantSetting })

  const updateMutation = useMutation({
    mutationFn: (payload: AssistantSettingUpdate) => updateAssistantSetting(payload),
    onSuccess: (data) => qc.setQueryData(KEY, data),
  })

  const testMutation = useMutation({
    mutationFn: (payload: AssistantSettingUpdate = {}) => testAssistantSetting(payload),
  })

  return {
    setting: query.data,
    isLoading: query.isLoading,
    error: query.error,
    update: updateMutation.mutateAsync,
    isUpdating: updateMutation.isPending,
    test: testMutation.mutateAsync,
    isTesting: testMutation.isPending,
    testResult: testMutation.data,
  }
}
