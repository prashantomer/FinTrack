import client from './client'
import type { Follio, FollioCreate, FollioUpdate } from '@/types'

export const listFollios = () =>
  client.get<Follio[]>('/follios/').then(r => r.data)

export const createFollio = (data: FollioCreate) =>
  client.post<Follio>('/follios/', data).then(r => r.data)

export const updateFollio = (id: number, data: FollioUpdate) =>
  client.put<Follio>(`/follios/${id}`, data).then(r => r.data)

export const deleteFollio = (id: number) =>
  client.delete(`/follios/${id}`)
