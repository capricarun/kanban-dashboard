import { useState } from 'react'
import { TaskProvider } from './context/TaskContext'
import { TaskBoard } from './components/TaskBoard/TaskBoard'
import { TaskForm } from './components/TaskBoard/TaskForm'
import { TaskModal } from './components/TaskBoard/TaskModal'

export default function App() {
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null)

  return (
    <TaskProvider>
      <div className="min-h-screen bg-gray-50 p-4 md:p-6">
        <div className="mx-auto w-full max-w-6xl">
          <header className="mb-4 flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Kanban Task Manager</h1>
              <p className="mt-1 text-sm text-gray-600">
                Create tasks, drag between columns, and persist changes locally.
              </p>
            </div>
          </header>

          <TaskForm />
          <TaskBoard onOpenTask={(taskId) => setSelectedTaskId(taskId)} />

          {selectedTaskId ? (
            <TaskModal taskId={selectedTaskId} onClose={() => setSelectedTaskId(null)} />
          ) : null}
        </div>
      </div>
    </TaskProvider>
  )
}
// Webhook test
// Blue-green deploy test
