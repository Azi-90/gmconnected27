import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'

export interface NewsArticle {
  id: string
  headline: string
  body: string
  eventType: string
  teamIds: string[]
  createdAt: string
}

function mapArticleRow(row: any): NewsArticle {
  return {
    id: row.id,
    headline: row.headline,
    body: row.body,
    eventType: row.event_type,
    teamIds: row.team_ids ?? [],
    createdAt: row.created_at,
  }
}

export function useNews() {
  const [articles, setArticles] = useState<NewsArticle[]>([])
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    const { data } = await supabase
      .from('news_articles')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50)
    setArticles((data ?? []).map(mapArticleRow))
    setLoading(false)
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  return { articles, loading, refresh }
}
