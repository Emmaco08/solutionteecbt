export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      access_rules: {
        Row: {
          rules: Json
          tier: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          rules: Json
          tier: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          rules?: Json
          tier?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      ad_campaign_seen: {
        Row: {
          campaign_id: string
          day: string
          user_id: string
          views: number
        }
        Insert: {
          campaign_id: string
          day: string
          user_id: string
          views?: number
        }
        Update: {
          campaign_id?: string
          day?: string
          user_id?: string
          views?: number
        }
        Relationships: [
          {
            foreignKeyName: "ad_campaign_seen_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "ad_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      ad_campaign_stats: {
        Row: {
          campaign_id: string
          clicks: number
          day: string
          placement: string
          views: number
        }
        Insert: {
          campaign_id: string
          clicks?: number
          day: string
          placement: string
          views?: number
        }
        Update: {
          campaign_id?: string
          clicks?: number
          day?: string
          placement?: string
          views?: number
        }
        Relationships: [
          {
            foreignKeyName: "ad_campaign_stats_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "ad_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      ad_campaigns: {
        Row: {
          banner_key: string | null
          brand: string
          break_key: string | null
          break_kind: string
          cap_per_day: number
          card_body: string | null
          card_key: string | null
          card_title: string | null
          created_at: string
          created_by: string | null
          cta: string
          ends_on: string | null
          id: string
          link: string | null
          name: string
          placements: string[]
          share_pct: number
          skip_after_s: number
          starts_on: string | null
          status: string
          updated_at: string
          video_key: string | null
          weight: number
        }
        Insert: {
          banner_key?: string | null
          brand: string
          break_key?: string | null
          break_kind?: string
          cap_per_day?: number
          card_body?: string | null
          card_key?: string | null
          card_title?: string | null
          created_at?: string
          created_by?: string | null
          cta?: string
          ends_on?: string | null
          id?: string
          link?: string | null
          name: string
          placements?: string[]
          share_pct?: number
          skip_after_s?: number
          starts_on?: string | null
          status?: string
          updated_at?: string
          video_key?: string | null
          weight?: number
        }
        Update: {
          banner_key?: string | null
          brand?: string
          break_key?: string | null
          break_kind?: string
          cap_per_day?: number
          card_body?: string | null
          card_key?: string | null
          card_title?: string | null
          created_at?: string
          created_by?: string | null
          cta?: string
          ends_on?: string | null
          id?: string
          link?: string | null
          name?: string
          placements?: string[]
          share_pct?: number
          skip_after_s?: number
          starts_on?: string | null
          status?: string
          updated_at?: string
          video_key?: string | null
          weight?: number
        }
        Relationships: []
      }
      ad_daily: {
        Row: {
          clicks: number
          day: string
          format: string
          impressions: number
          placement: string
        }
        Insert: {
          clicks?: number
          day?: string
          format: string
          impressions?: number
          placement?: string
        }
        Update: {
          clicks?: number
          day?: string
          format?: string
          impressions?: number
          placement?: string
        }
        Relationships: []
      }
      ad_progress: {
        Row: {
          count: number
          kind: string
          ref: string
          updated_at: string
          user_id: string
        }
        Insert: {
          count?: number
          kind: string
          ref?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          count?: number
          kind?: string
          ref?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      ad_rewards: {
        Row: {
          ad_unit: string | null
          created_at: string
          expires_at: string | null
          granted_at: string | null
          id: string
          kind: string
          ref: string | null
          status: string
          transaction_id: string | null
          user_id: string
          via: string | null
        }
        Insert: {
          ad_unit?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string | null
          id?: string
          kind: string
          ref?: string | null
          status?: string
          transaction_id?: string | null
          user_id: string
          via?: string | null
        }
        Update: {
          ad_unit?: string | null
          created_at?: string
          expires_at?: string | null
          granted_at?: string | null
          id?: string
          kind?: string
          ref?: string | null
          status?: string
          transaction_id?: string | null
          user_id?: string
          via?: string | null
        }
        Relationships: []
      }
      ai_cache: {
        Row: {
          answer: string
          created_at: string
          hits: number
          key: string
          model: string | null
        }
        Insert: {
          answer: string
          created_at?: string
          hits?: number
          key: string
          model?: string | null
        }
        Update: {
          answer?: string
          created_at?: string
          hits?: number
          key?: string
          model?: string | null
        }
        Relationships: []
      }
      ai_calls: {
        Row: {
          at: string
          error: string | null
          id: number
          model: string | null
          ms: number | null
          ok: boolean
          provider: string | null
          purpose: string | null
        }
        Insert: {
          at?: string
          error?: string | null
          id?: never
          model?: string | null
          ms?: number | null
          ok: boolean
          provider?: string | null
          purpose?: string | null
        }
        Update: {
          at?: string
          error?: string | null
          id?: never
          model?: string | null
          ms?: number | null
          ok?: boolean
          provider?: string | null
          purpose?: string | null
        }
        Relationships: []
      }
      ai_chats: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          subject_id: number | null
          summary: string | null
          summary_upto: string | null
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          subject_id?: number | null
          summary?: string | null
          summary_upto?: string | null
          title?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          subject_id?: number | null
          summary?: string | null
          summary_upto?: string | null
          title?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_chats_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_chunks: {
        Row: {
          content: string
          created_at: string
          embedding: string
          id: number
          source: string
          source_id: string
          subject_id: number | null
          title: string | null
        }
        Insert: {
          content: string
          created_at?: string
          embedding: string
          id?: never
          source: string
          source_id: string
          subject_id?: number | null
          title?: string | null
        }
        Update: {
          content?: string
          created_at?: string
          embedding?: string
          id?: never
          source?: string
          source_id?: string
          subject_id?: number | null
          title?: string | null
        }
        Relationships: []
      }
      ai_gen_questions: {
        Row: {
          answer: string
          body: string
          chat_id: string | null
          created_at: string
          explanation: string | null
          id: string
          options: Json
          subject: string | null
          topic: string | null
          user_id: string
        }
        Insert: {
          answer: string
          body: string
          chat_id?: string | null
          created_at?: string
          explanation?: string | null
          id?: string
          options: Json
          subject?: string | null
          topic?: string | null
          user_id: string
        }
        Update: {
          answer?: string
          body?: string
          chat_id?: string | null
          created_at?: string
          explanation?: string | null
          id?: string
          options?: Json
          subject?: string | null
          topic?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_gen_questions_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "ai_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_messages: {
        Row: {
          card: Json | null
          chat_id: string
          content: string
          created_at: string
          flag_reason: string | null
          flagged_at: string | null
          has_image: boolean
          hint: boolean
          id: string
          model: string | null
          ms: number | null
          provider: string | null
          question_id: string | null
          reaction: string | null
          role: string
          user_id: string
        }
        Insert: {
          card?: Json | null
          chat_id: string
          content?: string
          created_at?: string
          flag_reason?: string | null
          flagged_at?: string | null
          has_image?: boolean
          hint?: boolean
          id?: string
          model?: string | null
          ms?: number | null
          provider?: string | null
          question_id?: string | null
          reaction?: string | null
          role: string
          user_id: string
        }
        Update: {
          card?: Json | null
          chat_id?: string
          content?: string
          created_at?: string
          flag_reason?: string | null
          flagged_at?: string | null
          has_image?: boolean
          hint?: boolean
          id?: string
          model?: string | null
          ms?: number | null
          provider?: string | null
          question_id?: string | null
          reaction?: string | null
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_messages_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "ai_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_messages_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_models: {
        Row: {
          created_at: string
          dimensions: number | null
          enabled: boolean
          id: string
          label: string | null
          max_tokens: number
          model: string
          params: Json
          priority: number
          provider_id: string
          purpose: string
          temperature: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          dimensions?: number | null
          enabled?: boolean
          id?: string
          label?: string | null
          max_tokens?: number
          model: string
          params?: Json
          priority?: number
          provider_id: string
          purpose: string
          temperature?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          dimensions?: number | null
          enabled?: boolean
          id?: string
          label?: string | null
          max_tokens?: number
          model?: string
          params?: Json
          priority?: number
          provider_id?: string
          purpose?: string
          temperature?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_models_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "ai_providers"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_prompts: {
        Row: {
          active: boolean
          body: string
          created_at: string
          created_by: string | null
          id: number
          notes: string | null
          version: number
        }
        Insert: {
          active?: boolean
          body: string
          created_at?: string
          created_by?: string | null
          id?: never
          notes?: string | null
          version: number
        }
        Update: {
          active?: boolean
          body?: string
          created_at?: string
          created_by?: string | null
          id?: never
          notes?: string | null
          version?: number
        }
        Relationships: []
      }
      ai_providers: {
        Row: {
          base_url: string
          created_at: string
          enabled: boolean
          id: string
          key_hint: string | null
          key_secret: string | null
          name: string
          notes: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          base_url: string
          created_at?: string
          enabled?: boolean
          id?: string
          key_hint?: string | null
          key_secret?: string | null
          name: string
          notes?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          base_url?: string
          created_at?: string
          enabled?: boolean
          id?: string
          key_hint?: string | null
          key_secret?: string | null
          name?: string
          notes?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      ai_safety: {
        Row: {
          blocked_until: string | null
          decided_at: string | null
          decided_by: string | null
          decision: string | null
          forever: boolean
          level: number
          reason: string | null
          reported_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          blocked_until?: string | null
          decided_at?: string | null
          decided_by?: string | null
          decision?: string | null
          forever?: boolean
          level?: number
          reason?: string | null
          reported_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          blocked_until?: string | null
          decided_at?: string | null
          decided_by?: string | null
          decision?: string | null
          forever?: boolean
          level?: number
          reason?: string | null
          reported_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      ai_strikes: {
        Row: {
          at: string
          id: number
          kind: string
          text: string | null
          user_id: string
        }
        Insert: {
          at?: string
          id?: never
          kind?: string
          text?: string | null
          user_id: string
        }
        Update: {
          at?: string
          id?: never
          kind?: string
          text?: string | null
          user_id?: string
        }
        Relationships: []
      }
      ai_tools_log: {
        Row: {
          args: Json
          at: string
          chat_id: string | null
          id: number
          ms: number | null
          note: string | null
          ok: boolean
          tool: string
          user_id: string
        }
        Insert: {
          args?: Json
          at?: string
          chat_id?: string | null
          id?: never
          ms?: number | null
          note?: string | null
          ok: boolean
          tool: string
          user_id: string
        }
        Update: {
          args?: Json
          at?: string
          chat_id?: string | null
          id?: never
          ms?: number | null
          note?: string | null
          ok?: boolean
          tool?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_tools_log_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "ai_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_usage: {
        Row: {
          day: string
          used: number
          user_id: string
        }
        Insert: {
          day: string
          used?: number
          user_id: string
        }
        Update: {
          day?: string
          used?: number
          user_id?: string
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          description: string | null
          is_public: boolean
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
        }
        Insert: {
          description?: string | null
          is_public?: boolean
          key: string
          updated_at?: string
          updated_by?: string | null
          value: Json
        }
        Update: {
          description?: string | null
          is_public?: boolean
          key?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
        }
        Relationships: []
      }
      app_tabs: {
        Row: {
          config: Json
          enabled: boolean
          icon: string
          key: string
          min_app_version: string | null
          premium_only: boolean
          sort: number
          title: string
          type: string
        }
        Insert: {
          config?: Json
          enabled?: boolean
          icon: string
          key: string
          min_app_version?: string | null
          premium_only?: boolean
          sort?: number
          title: string
          type: string
        }
        Update: {
          config?: Json
          enabled?: boolean
          icon?: string
          key?: string
          min_app_version?: string | null
          premium_only?: boolean
          sort?: number
          title?: string
          type?: string
        }
        Relationships: []
      }
      arena_answers: {
        Row: {
          arena_id: string
          choice: string | null
          correct: boolean
          idx: number
          ms: number
          points: number
          user_id: string
        }
        Insert: {
          arena_id: string
          choice?: string | null
          correct: boolean
          idx: number
          ms: number
          points: number
          user_id: string
        }
        Update: {
          arena_id?: string
          choice?: string | null
          correct?: boolean
          idx?: number
          ms?: number
          points?: number
          user_id?: string
        }
        Relationships: []
      }
      arena_players: {
        Row: {
          arena_id: string
          correct: number
          joined_at: string
          score: number
          user_id: string
          xp: number
        }
        Insert: {
          arena_id: string
          correct?: number
          joined_at?: string
          score?: number
          user_id: string
          xp?: number
        }
        Update: {
          arena_id?: string
          correct?: number
          joined_at?: string
          score?: number
          user_id?: string
          xp?: number
        }
        Relationships: []
      }
      arenas: {
        Row: {
          created_at: string
          created_by: string | null
          exam_id: number
          gap: number
          id: string
          max_players: number
          q_count: number
          question_ids: string[] | null
          reminded_at: string | null
          rewarded_at: string | null
          seconds: number
          starts_at: string
          status: string
          subject_id: number | null
          title: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          exam_id: number
          gap?: number
          id?: string
          max_players?: number
          q_count?: number
          question_ids?: string[] | null
          reminded_at?: string | null
          rewarded_at?: string | null
          seconds?: number
          starts_at: string
          status?: string
          subject_id?: number | null
          title: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          exam_id?: number
          gap?: number
          id?: string
          max_players?: number
          q_count?: number
          question_ids?: string[] | null
          reminded_at?: string | null
          rewarded_at?: string | null
          seconds?: number
          starts_at?: string
          status?: string
          subject_id?: number | null
          title?: string
        }
        Relationships: []
      }
      attempt_answers: {
        Row: {
          attempt_id: string
          choice: string | null
          flagged: boolean
          is_correct: boolean
          question_id: string
          time_ms: number | null
        }
        Insert: {
          attempt_id: string
          choice?: string | null
          flagged?: boolean
          is_correct?: boolean
          question_id: string
          time_ms?: number | null
        }
        Update: {
          attempt_id?: string
          choice?: string | null
          flagged?: boolean
          is_correct?: boolean
          question_id?: string
          time_ms?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "attempt_answers_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: false
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempt_answers_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      attempts: {
        Row: {
          client_score: Json | null
          config: Json
          exam_id: number
          fair: Json | null
          id: string
          mode: string
          question_ids: string[]
          risk: number | null
          server_score: Json
          started_at: string
          status: Database["public"]["Enums"]["attempt_status"]
          submitted_at: string
          synced_at: string
          time_used_s: number
          user_id: string
        }
        Insert: {
          client_score?: Json | null
          config?: Json
          exam_id: number
          fair?: Json | null
          id: string
          mode: string
          question_ids: string[]
          risk?: number | null
          server_score: Json
          started_at: string
          status?: Database["public"]["Enums"]["attempt_status"]
          submitted_at: string
          synced_at?: string
          time_used_s: number
          user_id: string
        }
        Update: {
          client_score?: Json | null
          config?: Json
          exam_id?: number
          fair?: Json | null
          id?: string
          mode?: string
          question_ids?: string[]
          risk?: number | null
          server_score?: Json
          started_at?: string
          status?: Database["public"]["Enums"]["attempt_status"]
          submitted_at?: string
          synced_at?: string
          time_used_s?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attempts_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor: string | null
          after: Json | null
          at: string
          before: Json | null
          id: number
          row_id: string | null
          table_name: string
        }
        Insert: {
          action: string
          actor?: string | null
          after?: Json | null
          at?: string
          before?: Json | null
          id?: never
          row_id?: string | null
          table_name: string
        }
        Update: {
          action?: string
          actor?: string | null
          after?: Json | null
          at?: string
          before?: Json | null
          id?: never
          row_id?: string | null
          table_name?: string
        }
        Relationships: []
      }
      auto_safety: {
        Row: {
          banned_at: string | null
          kinds: number
          score: number
          updated_at: string
          user_id: string
          warned_at: string | null
        }
        Insert: {
          banned_at?: string | null
          kinds?: number
          score?: number
          updated_at?: string
          user_id: string
          warned_at?: string | null
        }
        Update: {
          banned_at?: string | null
          kinds?: number
          score?: number
          updated_at?: string
          user_id?: string
          warned_at?: string | null
        }
        Relationships: []
      }
      badge_first_checks: {
        Row: {
          checked_at: string
          user_id: string
        }
        Insert: {
          checked_at?: string
          user_id: string
        }
        Update: {
          checked_at?: string
          user_id?: string
        }
        Relationships: []
      }
      badges: {
        Row: {
          active: boolean
          created_at: string
          description: string
          icon: string
          id: number
          key: string
          metric: string
          name: string
          rewards: Json
          sort: number
          targets: Json
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          description: string
          icon?: string
          id?: number
          key: string
          metric: string
          name: string
          rewards?: Json
          sort?: number
          targets: Json
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string
          icon?: string
          id?: number
          key?: string
          metric?: string
          name?: string
          rewards?: Json
          sort?: number
          targets?: Json
          updated_at?: string
        }
        Relationships: []
      }
      ban_appeals: {
        Row: {
          admin_note: string | null
          banned_at: string
          created_at: string
          decided_at: string | null
          decided_by: string | null
          id: string
          reason: string
          status: string
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          banned_at: string
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          id?: string
          reason: string
          status?: string
          user_id: string
        }
        Update: {
          admin_note?: string | null
          banned_at?: string
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          id?: string
          reason?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ban_appeals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      banned_devices: {
        Row: {
          banned_at: string
          banned_by: string | null
          device_hash: string
          lifted_at: string | null
          lifted_by: string | null
          reason: string
        }
        Insert: {
          banned_at?: string
          banned_by?: string | null
          device_hash: string
          lifted_at?: string | null
          lifted_by?: string | null
          reason: string
        }
        Update: {
          banned_at?: string
          banned_by?: string | null
          device_hash?: string
          lifted_at?: string | null
          lifted_by?: string | null
          reason?: string
        }
        Relationships: []
      }
      bookmarks: {
        Row: {
          created_at: string
          kind: string
          label: string | null
          ref: string
          user_id: string
        }
        Insert: {
          created_at?: string
          kind: string
          label?: string | null
          ref: string
          user_id?: string
        }
        Update: {
          created_at?: string
          kind?: string
          label?: string | null
          ref?: string
          user_id?: string
        }
        Relationships: []
      }
      careers: {
        Row: {
          active: boolean
          after_school: string | null
          checked: boolean
          course: string
          earnings: string | null
          field: string
          id: number
          jamb_note: string | null
          jamb_subjects: string[]
          name: string
          olevel: string | null
          skills: string[]
          sort: number
          summary: string
          universities: string[]
          updated_at: string
          years: number
        }
        Insert: {
          active?: boolean
          after_school?: string | null
          checked?: boolean
          course: string
          earnings?: string | null
          field: string
          id?: never
          jamb_note?: string | null
          jamb_subjects?: string[]
          name: string
          olevel?: string | null
          skills?: string[]
          sort?: number
          summary: string
          universities?: string[]
          updated_at?: string
          years?: number
        }
        Update: {
          active?: boolean
          after_school?: string | null
          checked?: boolean
          course?: string
          earnings?: string | null
          field?: string
          id?: never
          jamb_note?: string | null
          jamb_subjects?: string[]
          name?: string
          olevel?: string | null
          skills?: string[]
          sort?: number
          summary?: string
          universities?: string[]
          updated_at?: string
          years?: number
        }
        Relationships: []
      }
      challenge_access: {
        Row: {
          at: string
          challenge_id: string
          user_id: string
          via: string
        }
        Insert: {
          at?: string
          challenge_id: string
          user_id: string
          via: string
        }
        Update: {
          at?: string
          challenge_id?: string
          user_id?: string
          via?: string
        }
        Relationships: [
          {
            foreignKeyName: "challenge_access_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "challenges"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_answers: {
        Row: {
          answered_at: string
          choice: string | null
          correct: boolean | null
          entry_id: string
          question_id: string
          time_ms: number
        }
        Insert: {
          answered_at?: string
          choice?: string | null
          correct?: boolean | null
          entry_id: string
          question_id: string
          time_ms: number
        }
        Update: {
          answered_at?: string
          choice?: string | null
          correct?: boolean | null
          entry_id?: string
          question_id?: string
          time_ms?: number
        }
        Relationships: [
          {
            foreignKeyName: "challenge_answers_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: false
            referencedRelation: "challenge_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "challenge_answers_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "challenge_questions"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_appeals: {
        Row: {
          admin_note: string | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          entry_id: string
          id: string
          image_path: string | null
          reason: string
          status: string
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          entry_id: string
          id?: string
          image_path?: string | null
          reason: string
          status?: string
          user_id: string
        }
        Update: {
          admin_note?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          entry_id?: string
          id?: string
          image_path?: string | null
          reason?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "challenge_appeals_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: true
            referencedRelation: "challenge_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_entries: {
        Row: {
          away_ms: number
          challenge_id: string
          current: number
          deadline: string | null
          device_flags: string[]
          device_hash: string | null
          dq_reason: string | null
          exits: number
          finished_at: string | null
          flags: string[]
          id: string
          premium_given: boolean
          prize: number | null
          question_order: string[]
          rank: number | null
          review: string | null
          score: number
          served_at: string | null
          started_at: string
          status: string
          subject_scores: Json | null
          subjects: number[] | null
          time_ms: number
          user_id: string
          via: string | null
        }
        Insert: {
          away_ms?: number
          challenge_id: string
          current?: number
          deadline?: string | null
          device_flags?: string[]
          device_hash?: string | null
          dq_reason?: string | null
          exits?: number
          finished_at?: string | null
          flags?: string[]
          id?: string
          premium_given?: boolean
          prize?: number | null
          question_order: string[]
          rank?: number | null
          review?: string | null
          score?: number
          served_at?: string | null
          started_at?: string
          status?: string
          subject_scores?: Json | null
          subjects?: number[] | null
          time_ms?: number
          user_id: string
          via?: string | null
        }
        Update: {
          away_ms?: number
          challenge_id?: string
          current?: number
          deadline?: string | null
          device_flags?: string[]
          device_hash?: string | null
          dq_reason?: string | null
          exits?: number
          finished_at?: string | null
          flags?: string[]
          id?: string
          premium_given?: boolean
          prize?: number | null
          question_order?: string[]
          rank?: number | null
          review?: string | null
          score?: number
          served_at?: string | null
          started_at?: string
          status?: string
          subject_scores?: Json | null
          subjects?: number[] | null
          time_ms?: number
          user_id?: string
          via?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "challenge_entries_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "challenges"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_events: {
        Row: {
          at: string
          entry_id: string
          id: number
          kind: string
          ms: number | null
        }
        Insert: {
          at?: string
          entry_id: string
          id?: never
          kind: string
          ms?: number | null
        }
        Update: {
          at?: string
          entry_id?: string
          id?: never
          kind?: string
          ms?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "challenge_events_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: false
            referencedRelation: "challenge_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_invites: {
        Row: {
          challenge_id: string
          claimed_at: string | null
          code_hash: string
          code_hint: string | null
          created_at: string
          id: string
          label: string
          user_id: string | null
        }
        Insert: {
          challenge_id: string
          claimed_at?: string | null
          code_hash: string
          code_hint?: string | null
          created_at?: string
          id?: string
          label: string
          user_id?: string | null
        }
        Update: {
          challenge_id?: string
          claimed_at?: string | null
          code_hash?: string
          code_hint?: string | null
          created_at?: string
          id?: string
          label?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "challenge_invites_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "challenges"
            referencedColumns: ["id"]
          },
        ]
      }
      challenge_questions: {
        Row: {
          answer: string
          body: string
          challenge_id: string
          created_at: string
          difficulty: string
          explanation: string | null
          id: string
          image_path: string | null
          number: number | null
          options: Json
          passage_body: string | null
          passage_key: string | null
          passage_title: string | null
          position: number
          section: string | null
          source_question_id: string | null
          subject_id: number | null
          topic: string | null
        }
        Insert: {
          answer: string
          body: string
          challenge_id: string
          created_at?: string
          difficulty?: string
          explanation?: string | null
          id?: string
          image_path?: string | null
          number?: number | null
          options: Json
          passage_body?: string | null
          passage_key?: string | null
          passage_title?: string | null
          position?: number
          section?: string | null
          source_question_id?: string | null
          subject_id?: number | null
          topic?: string | null
        }
        Update: {
          answer?: string
          body?: string
          challenge_id?: string
          created_at?: string
          difficulty?: string
          explanation?: string | null
          id?: string
          image_path?: string | null
          number?: number | null
          options?: Json
          passage_body?: string | null
          passage_key?: string | null
          passage_title?: string | null
          position?: number
          section?: string | null
          source_question_id?: string | null
          subject_id?: number | null
          topic?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "challenge_questions_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "challenges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "challenge_questions_source_question_id_fkey"
            columns: ["source_question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "challenge_questions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      challenges: {
        Row: {
          access: string
          access_code_hash: string | null
          allow_calculator: boolean
          allow_review: boolean
          allowed_exits: number
          announced_at: string | null
          bg_dark: string | null
          bg_light: string | null
          closed_at: string | null
          created_at: string
          created_by: string | null
          duration_minutes: number | null
          end_notified_at: string | null
          ends_at: string
          exam_code: string | null
          exit_action: string
          icon: string
          id: string
          kind: string
          max_away_seconds: number | null
          max_players: number | null
          min_win_pct: number | null
          mock_subjects: Json
          mode: string
          per_level: Json
          premium_days: number
          premium_top: number
          prizes: number[]
          published: boolean
          results: string
          reward_text: string | null
          same_questions: boolean
          seconds_per_question: number
          soon_notified_at: string | null
          starts_at: string
          style: string
          subject_id: number | null
          subtitle: string | null
          title: string
          updated_at: string
          xp_fee: number
        }
        Insert: {
          access?: string
          access_code_hash?: string | null
          allow_calculator?: boolean
          allow_review?: boolean
          allowed_exits?: number
          announced_at?: string | null
          bg_dark?: string | null
          bg_light?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          duration_minutes?: number | null
          end_notified_at?: string | null
          ends_at: string
          exam_code?: string | null
          exit_action?: string
          icon?: string
          id?: string
          kind?: string
          max_away_seconds?: number | null
          max_players?: number | null
          min_win_pct?: number | null
          mock_subjects?: Json
          mode?: string
          per_level?: Json
          premium_days?: number
          premium_top?: number
          prizes?: number[]
          published?: boolean
          results?: string
          reward_text?: string | null
          same_questions?: boolean
          seconds_per_question?: number
          soon_notified_at?: string | null
          starts_at: string
          style?: string
          subject_id?: number | null
          subtitle?: string | null
          title: string
          updated_at?: string
          xp_fee?: number
        }
        Update: {
          access?: string
          access_code_hash?: string | null
          allow_calculator?: boolean
          allow_review?: boolean
          allowed_exits?: number
          announced_at?: string | null
          bg_dark?: string | null
          bg_light?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          duration_minutes?: number | null
          end_notified_at?: string | null
          ends_at?: string
          exam_code?: string | null
          exit_action?: string
          icon?: string
          id?: string
          kind?: string
          max_away_seconds?: number | null
          max_players?: number | null
          min_win_pct?: number | null
          mock_subjects?: Json
          mode?: string
          per_level?: Json
          premium_days?: number
          premium_top?: number
          prizes?: number[]
          published?: boolean
          results?: string
          reward_text?: string | null
          same_questions?: boolean
          seconds_per_question?: number
          soon_notified_at?: string | null
          starts_at?: string
          style?: string
          subject_id?: number | null
          subtitle?: string | null
          title?: string
          updated_at?: string
          xp_fee?: number
        }
        Relationships: [
          {
            foreignKeyName: "challenges_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      class_assignments: {
        Row: {
          class_id: string
          created_at: string
          due_at: string | null
          id: string
          instructions: string | null
          max_score: number
          title: string
        }
        Insert: {
          class_id: string
          created_at?: string
          due_at?: string | null
          id?: string
          instructions?: string | null
          max_score?: number
          title: string
        }
        Update: {
          class_id?: string
          created_at?: string
          due_at?: string | null
          id?: string
          instructions?: string | null
          max_score?: number
          title?: string
        }
        Relationships: []
      }
      class_links: {
        Row: {
          class_id: string
          join_url: string | null
          recording_url: string | null
          updated_at: string
        }
        Insert: {
          class_id: string
          join_url?: string | null
          recording_url?: string | null
          updated_at?: string
        }
        Update: {
          class_id?: string
          join_url?: string | null
          recording_url?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      class_materials: {
        Row: {
          class_id: string
          created_at: string
          id: string
          title: string
          url: string
        }
        Insert: {
          class_id: string
          created_at?: string
          id?: string
          title: string
          url: string
        }
        Update: {
          class_id?: string
          created_at?: string
          id?: string
          title?: string
          url?: string
        }
        Relationships: []
      }
      class_registrations: {
        Row: {
          class_id: string
          created_at: string
          joined_at: string | null
          payment_id: string | null
          user_id: string
        }
        Insert: {
          class_id: string
          created_at?: string
          joined_at?: string | null
          payment_id?: string | null
          user_id: string
        }
        Update: {
          class_id?: string
          created_at?: string
          joined_at?: string | null
          payment_id?: string | null
          user_id?: string
        }
        Relationships: []
      }
      class_submissions: {
        Row: {
          answer: string
          assignment_id: string
          feedback: string | null
          marked_at: string | null
          marked_by: string | null
          score: number | null
          submitted_at: string
          user_id: string
        }
        Insert: {
          answer: string
          assignment_id: string
          feedback?: string | null
          marked_at?: string | null
          marked_by?: string | null
          score?: number | null
          submitted_at?: string
          user_id: string
        }
        Update: {
          answer?: string
          assignment_id?: string
          feedback?: string | null
          marked_at?: string | null
          marked_by?: string | null
          score?: number | null
          submitted_at?: string
          user_id?: string
        }
        Relationships: []
      }
      classes: {
        Row: {
          about: string | null
          access: string
          created_at: string
          created_by: string | null
          exam: string | null
          id: string
          minutes: number
          price_kobo: number | null
          seats: number | null
          starts_at: string
          status: string
          subject_id: number | null
          teacher: string
          title: string
          updated_at: string
          web_only: boolean
        }
        Insert: {
          about?: string | null
          access?: string
          created_at?: string
          created_by?: string | null
          exam?: string | null
          id?: string
          minutes?: number
          price_kobo?: number | null
          seats?: number | null
          starts_at: string
          status?: string
          subject_id?: number | null
          teacher: string
          title: string
          updated_at?: string
          web_only?: boolean
        }
        Update: {
          about?: string | null
          access?: string
          created_at?: string
          created_by?: string | null
          exam?: string | null
          id?: string
          minutes?: number
          price_kobo?: number | null
          seats?: number | null
          starts_at?: string
          status?: string
          subject_id?: number | null
          teacher?: string
          title?: string
          updated_at?: string
          web_only?: boolean
        }
        Relationships: []
      }
      community_blocks: {
        Row: {
          blocked: string
          blocker: string
          created_at: string
        }
        Insert: {
          blocked: string
          blocker: string
          created_at?: string
        }
        Update: {
          blocked?: string
          blocker?: string
          created_at?: string
        }
        Relationships: []
      }
      community_comments: {
        Row: {
          body: string
          checked_at: string | null
          created_at: string
          from_ai: boolean
          id: number
          post_id: string
          reason: string | null
          status: string
          user_id: string | null
        }
        Insert: {
          body: string
          checked_at?: string | null
          created_at?: string
          from_ai?: boolean
          id?: number
          post_id: string
          reason?: string | null
          status?: string
          user_id?: string | null
        }
        Update: {
          body?: string
          checked_at?: string | null
          created_at?: string
          from_ai?: boolean
          id?: number
          post_id?: string
          reason?: string | null
          status?: string
          user_id?: string | null
        }
        Relationships: []
      }
      community_follows: {
        Row: {
          created_at: string
          followee: string
          follower: string
        }
        Insert: {
          created_at?: string
          followee: string
          follower: string
        }
        Update: {
          created_at?: string
          followee?: string
          follower?: string
        }
        Relationships: []
      }
      community_likes: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: []
      }
      community_posts: {
        Row: {
          ai_answered: boolean
          ask_ai: boolean
          body: string
          checked_at: string | null
          comments_count: number
          created_at: string
          id: string
          image_path: string | null
          likes_count: number
          reason: string | null
          status: string
          subject_id: number | null
          user_id: string
        }
        Insert: {
          ai_answered?: boolean
          ask_ai?: boolean
          body: string
          checked_at?: string | null
          comments_count?: number
          created_at?: string
          id?: string
          image_path?: string | null
          likes_count?: number
          reason?: string | null
          status?: string
          subject_id?: number | null
          user_id: string
        }
        Update: {
          ai_answered?: boolean
          ask_ai?: boolean
          body?: string
          checked_at?: string | null
          comments_count?: number
          created_at?: string
          id?: string
          image_path?: string | null
          likes_count?: number
          reason?: string | null
          status?: string
          subject_id?: number | null
          user_id?: string
        }
        Relationships: []
      }
      community_reports: {
        Row: {
          created_at: string
          id: number
          kind: string
          reason: string | null
          ref: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: number
          kind: string
          reason?: string | null
          ref: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: number
          kind?: string
          reason?: string | null
          ref?: string
          user_id?: string
        }
        Relationships: []
      }
      content_purchases: {
        Row: {
          created_at: string
          kind: string
          payment_id: string | null
          ref: string
          user_id: string
        }
        Insert: {
          created_at?: string
          kind: string
          payment_id?: string | null
          ref: string
          user_id: string
        }
        Update: {
          created_at?: string
          kind?: string
          payment_id?: string | null
          ref?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "content_purchases_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      device_accounts: {
        Row: {
          allowed: boolean
          device_hash: string
          first_seen: string
          flags: string[]
          kind: string
          last_seen: string
          user_id: string
        }
        Insert: {
          allowed?: boolean
          device_hash: string
          first_seen?: string
          flags?: string[]
          kind?: string
          last_seen?: string
          user_id: string
        }
        Update: {
          allowed?: boolean
          device_hash?: string
          first_seen?: string
          flags?: string[]
          kind?: string
          last_seen?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_accounts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      device_appeals: {
        Row: {
          admin_note: string | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          device_hash: string
          email: string
          id: string
          reason: string
          status: string
        }
        Insert: {
          admin_note?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          device_hash: string
          email: string
          id?: string
          reason: string
          status?: string
        }
        Update: {
          admin_note?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          device_hash?: string
          email?: string
          id?: string
          reason?: string
          status?: string
        }
        Relationships: []
      }
      device_events: {
        Row: {
          at: string
          detail: string | null
          device_hash: string | null
          id: number
          kind: string
          user_id: string | null
        }
        Insert: {
          at?: string
          detail?: string | null
          device_hash?: string | null
          id?: never
          kind: string
          user_id?: string | null
        }
        Update: {
          at?: string
          detail?: string | null
          device_hash?: string | null
          id?: never
          kind?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "device_events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      entitlements: {
        Row: {
          created_at: string
          expires_at: string
          external_ref: string | null
          granted_by: string | null
          id: string
          plan_id: number | null
          reason: string | null
          revoked_at: string | null
          revoked_by: string | null
          source: Database["public"]["Enums"]["entitlement_source"]
          starts_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          external_ref?: string | null
          granted_by?: string | null
          id?: string
          plan_id?: number | null
          reason?: string | null
          revoked_at?: string | null
          revoked_by?: string | null
          source: Database["public"]["Enums"]["entitlement_source"]
          starts_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          external_ref?: string | null
          granted_by?: string | null
          id?: string
          plan_id?: number | null
          reason?: string | null
          revoked_at?: string | null
          revoked_by?: string | null
          source?: Database["public"]["Enums"]["entitlement_source"]
          starts_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "entitlements_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_blueprints: {
        Row: {
          exam_id: number
          id: number
          sections: Json
          subject_id: number | null
          total: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          exam_id: number
          id?: never
          sections?: Json
          subject_id?: number | null
          total: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          exam_id?: number
          id?: never
          sections?: Json
          subject_id?: number | null
          total?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "exam_blueprints_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exam_blueprints_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_bodies: {
        Row: {
          code: string
          id: number
          is_active: boolean
          logo_path: string | null
          name: string
          sort: number
          subtitle: string | null
        }
        Insert: {
          code: string
          id?: never
          is_active?: boolean
          logo_path?: string | null
          name: string
          sort?: number
          subtitle?: string | null
        }
        Update: {
          code?: string
          id?: never
          is_active?: boolean
          logo_path?: string | null
          name?: string
          sort?: number
          subtitle?: string | null
        }
        Relationships: []
      }
      exam_configs: {
        Row: {
          exam_id: number
          max_options: number
          rules: Json
          score_scale: number
          subjects_per_candidate: number
          total_minutes: number | null
        }
        Insert: {
          exam_id: number
          max_options?: number
          rules?: Json
          score_scale?: number
          subjects_per_candidate?: number
          total_minutes?: number | null
        }
        Update: {
          exam_id?: number
          max_options?: number
          rules?: Json
          score_scale?: number
          subjects_per_candidate?: number
          total_minutes?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "exam_configs_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: true
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_subjects: {
        Row: {
          compulsory: boolean
          exam_id: number
          minutes: number | null
          question_count: number
          subject_id: number
        }
        Insert: {
          compulsory?: boolean
          exam_id: number
          minutes?: number | null
          question_count?: number
          subject_id: number
        }
        Update: {
          compulsory?: boolean
          exam_id?: number
          minutes?: number | null
          question_count?: number
          subject_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "exam_subjects_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exam_subjects_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_years: {
        Row: {
          exam_id: number
          id: number
          published_at: string | null
          status: Database["public"]["Enums"]["year_status"]
          subject_id: number
          year: number
        }
        Insert: {
          exam_id: number
          id?: never
          published_at?: string | null
          status?: Database["public"]["Enums"]["year_status"]
          subject_id: number
          year: number
        }
        Update: {
          exam_id?: number
          id?: never
          published_at?: string | null
          status?: Database["public"]["Enums"]["year_status"]
          subject_id?: number
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "exam_years_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exam_years_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flags: {
        Row: {
          description: string | null
          enabled: boolean
          key: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          description?: string | null
          enabled?: boolean
          key: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          description?: string | null
          enabled?: boolean
          key?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      game_answers: {
        Row: {
          choice: string | null
          correct: boolean
          game_id: string
          idx: number
          ms: number
          points: number
          user_id: string
        }
        Insert: {
          choice?: string | null
          correct: boolean
          game_id: string
          idx: number
          ms: number
          points: number
          user_id: string
        }
        Update: {
          choice?: string | null
          correct?: boolean
          game_id?: string
          idx?: number
          ms?: number
          points?: number
          user_id?: string
        }
        Relationships: []
      }
      game_players: {
        Row: {
          correct: number
          cur: number
          finished_at: string | null
          game_id: string
          joined_at: string
          score: number
          served_at: string | null
          user_id: string
          xp: number
        }
        Insert: {
          correct?: number
          cur?: number
          finished_at?: string | null
          game_id: string
          joined_at?: string
          score?: number
          served_at?: string | null
          user_id: string
          xp?: number
        }
        Update: {
          correct?: number
          cur?: number
          finished_at?: string | null
          game_id?: string
          joined_at?: string
          score?: number
          served_at?: string | null
          user_id?: string
          xp?: number
        }
        Relationships: []
      }
      games: {
        Row: {
          bot: Json | null
          code: string | null
          created_at: string
          exam_id: number
          expires_at: string
          host: string
          id: string
          mode: string
          question_ids: string[]
          seconds: number
          status: string
          subject_id: number
        }
        Insert: {
          bot?: Json | null
          code?: string | null
          created_at?: string
          exam_id: number
          expires_at?: string
          host: string
          id?: string
          mode: string
          question_ids: string[]
          seconds?: number
          status?: string
          subject_id: number
        }
        Update: {
          bot?: Json | null
          code?: string | null
          created_at?: string
          exam_id?: number
          expires_at?: string
          host?: string
          id?: string
          mode?: string
          question_ids?: string[]
          seconds?: number
          status?: string
          subject_id?: number
        }
        Relationships: []
      }
      import_batches: {
        Row: {
          created_at: string
          created_by: string | null
          file_name: string
          id: string
          inserted_rows: number
          summary: Json
          total_rows: number
          undone_at: string | null
          undone_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          file_name: string
          id?: string
          inserted_rows?: number
          summary?: Json
          total_rows?: number
          undone_at?: string | null
          undone_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          file_name?: string
          id?: string
          inserted_rows?: number
          summary?: Json
          total_rows?: number
          undone_at?: string | null
          undone_by?: string | null
        }
        Relationships: []
      }
      lb_winners: {
        Row: {
          board: string
          created_at: string
          days_given: number
          id: number
          label: string
          period: string
          period_start: string
          rank: number
          score: number
          user_id: string
          xp_given: number
        }
        Insert: {
          board: string
          created_at?: string
          days_given?: number
          id?: number
          label: string
          period: string
          period_start: string
          rank: number
          score: number
          user_id: string
          xp_given?: number
        }
        Update: {
          board?: string
          created_at?: string
          days_given?: number
          id?: number
          label?: string
          period?: string
          period_start?: string
          rank?: number
          score?: number
          user_id?: string
          xp_given?: number
        }
        Relationships: [
          {
            foreignKeyName: "lb_winners_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      leaderboard_reviews: {
        Row: {
          attempt_id: string
          decided_at: string
          decided_by: string | null
          decision: string
        }
        Insert: {
          attempt_id: string
          decided_at?: string
          decided_by?: string | null
          decision: string
        }
        Update: {
          attempt_id?: string
          decided_at?: string
          decided_by?: string | null
          decision?: string
        }
        Relationships: [
          {
            foreignKeyName: "leaderboard_reviews_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: true
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
        ]
      }
      motivation_quotes: {
        Row: {
          active: boolean
          author: string | null
          body: string
          created_at: string
          id: number
          kind: string
          sort: number
        }
        Insert: {
          active?: boolean
          author?: string | null
          body: string
          created_at?: string
          id?: never
          kind?: string
          sort?: number
        }
        Update: {
          active?: boolean
          author?: string | null
          body?: string
          created_at?: string
          id?: never
          kind?: string
          sort?: number
        }
        Relationships: []
      }
      news_comment_reports: {
        Row: {
          comment_id: string
          created_at: string
          reason: string
          user_id: string
        }
        Insert: {
          comment_id: string
          created_at?: string
          reason: string
          user_id?: string
        }
        Update: {
          comment_id?: string
          created_at?: string
          reason?: string
          user_id?: string
        }
        Relationships: []
      }
      news_comments: {
        Row: {
          body: string
          created_at: string
          hidden_at: string | null
          hidden_by: string | null
          hidden_reason: string | null
          id: string
          post_id: string
          reports: number
          reviewed_at: string | null
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason?: string | null
          id?: string
          post_id: string
          reports?: number
          reviewed_at?: string | null
          user_id?: string
        }
        Update: {
          body?: string
          created_at?: string
          hidden_at?: string | null
          hidden_by?: string | null
          hidden_reason?: string | null
          id?: string
          post_id?: string
          reports?: number
          reviewed_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      news_likes: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id?: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: []
      }
      news_posts: {
        Row: {
          body: string | null
          category: string
          comments_on: boolean
          created_at: string
          created_by: string | null
          id: string
          image_path: string | null
          is_pinned: boolean
          link_target: string | null
          link_type: string | null
          notify: boolean
          publish_at: string
          status: Database["public"]["Enums"]["content_status"]
          summary: string | null
          title: string
          updated_at: string
        }
        Insert: {
          body?: string | null
          category?: string
          comments_on?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          image_path?: string | null
          is_pinned?: boolean
          link_target?: string | null
          link_type?: string | null
          notify?: boolean
          publish_at?: string
          status?: Database["public"]["Enums"]["content_status"]
          summary?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          body?: string | null
          category?: string
          comments_on?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          image_path?: string | null
          is_pinned?: boolean
          link_target?: string | null
          link_type?: string | null
          notify?: boolean
          publish_at?: string
          status?: Database["public"]["Enums"]["content_status"]
          summary?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      news_saves: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id?: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: []
      }
      notification_prefs: {
        Row: {
          enabled: boolean
          topic: Database["public"]["Enums"]["notif_topic"]
          updated_at: string
          user_id: string
        }
        Insert: {
          enabled: boolean
          topic: Database["public"]["Enums"]["notif_topic"]
          updated_at?: string
          user_id?: string
        }
        Update: {
          enabled?: boolean
          topic?: Database["public"]["Enums"]["notif_topic"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      notification_reads: {
        Row: {
          notification_id: string
          read_at: string
          user_id: string
        }
        Insert: {
          notification_id: string
          read_at?: string
          user_id?: string
        }
        Update: {
          notification_id?: string
          read_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_reads_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          audience: string
          body: string
          created_at: string
          created_by: string | null
          error: string | null
          id: string
          link: Json
          scheduled_at: string
          sent_at: string | null
          sent_count: number
          source: string
          source_ref: string | null
          status: string
          title: string
          topic: Database["public"]["Enums"]["notif_topic"]
          user_id: string | null
        }
        Insert: {
          audience?: string
          body: string
          created_at?: string
          created_by?: string | null
          error?: string | null
          id?: string
          link?: Json
          scheduled_at?: string
          sent_at?: string | null
          sent_count?: number
          source?: string
          source_ref?: string | null
          status?: string
          title: string
          topic: Database["public"]["Enums"]["notif_topic"]
          user_id?: string | null
        }
        Update: {
          audience?: string
          body?: string
          created_at?: string
          created_by?: string | null
          error?: string | null
          id?: string
          link?: Json
          scheduled_at?: string
          sent_at?: string | null
          sent_count?: number
          source?: string
          source_ref?: string | null
          status?: string
          title?: string
          topic?: Database["public"]["Enums"]["notif_topic"]
          user_id?: string | null
        }
        Relationships: []
      }
      onboarding_slides: {
        Row: {
          animation: string | null
          body: string
          enabled: boolean
          id: number
          sort: number
          title: string
        }
        Insert: {
          animation?: string | null
          body: string
          enabled?: boolean
          id?: never
          sort?: number
          title: string
        }
        Update: {
          animation?: string | null
          body?: string
          enabled?: boolean
          id?: never
          sort?: number
          title?: string
        }
        Relationships: []
      }
      passages: {
        Row: {
          body: string
          created_at: string
          created_by: string | null
          exam_id: number
          id: string
          subject_id: number
          title: string | null
          updated_at: string
          year: number | null
        }
        Insert: {
          body: string
          created_at?: string
          created_by?: string | null
          exam_id: number
          id?: string
          subject_id: number
          title?: string | null
          updated_at?: string
          year?: number | null
        }
        Update: {
          body?: string
          created_at?: string
          created_by?: string | null
          exam_id?: number
          id?: string
          subject_id?: number
          title?: string | null
          updated_at?: string
          year?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "passages_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "passages_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      pay_attempts: {
        Row: {
          action: string
          created_at: string
          id: number
          ok: boolean
          user_id: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: never
          ok: boolean
          user_id: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: never
          ok?: boolean
          user_id?: string
        }
        Relationships: []
      }
      payment_events: {
        Row: {
          created_at: string
          data: Json
          event_key: string | null
          id: number
          kind: string
          note: string | null
          ok: boolean
          payment_id: string | null
          provider: string
        }
        Insert: {
          created_at?: string
          data?: Json
          event_key?: string | null
          id?: never
          kind: string
          note?: string | null
          ok: boolean
          payment_id?: string | null
          provider: string
        }
        Update: {
          created_at?: string
          data?: Json
          event_key?: string | null
          id?: never
          kind?: string
          note?: string | null
          ok?: boolean
          payment_id?: string | null
          provider?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_events_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          fee_kobo: number
          amount_kobo: number
          channel: string | null
          code_id: string | null
          created_at: string
          currency: string
          discount_kobo: number
          entitlement_id: string | null
          id: string
          item_kind: string | null
          item_ref: string | null
          list_kobo: number
          live: boolean
          plan_id: number | null
          provider: string
          provider_data: Json
          purchase_token: string | null
          reference: string
          referral_friends: number
          refunded_at: string | null
          source: string
          status: Database["public"]["Enums"]["payment_status"]
          updated_at: string
          user_id: string | null
          verified_at: string | null
          xp_pack: number | null
        }
        Insert: {
          fee_kobo?: number
          amount_kobo: number
          channel?: string | null
          code_id?: string | null
          created_at?: string
          currency?: string
          discount_kobo?: number
          entitlement_id?: string | null
          id?: string
          item_kind?: string | null
          item_ref?: string | null
          list_kobo: number
          live: boolean
          plan_id?: number | null
          provider: string
          provider_data?: Json
          purchase_token?: string | null
          reference: string
          referral_friends?: number
          refunded_at?: string | null
          source?: string
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id?: string | null
          verified_at?: string | null
          xp_pack?: number | null
        }
        Update: {
          fee_kobo?: number
          amount_kobo?: number
          channel?: string | null
          code_id?: string | null
          created_at?: string
          currency?: string
          discount_kobo?: number
          entitlement_id?: string | null
          id?: string
          item_kind?: string | null
          item_ref?: string | null
          list_kobo?: number
          live?: boolean
          plan_id?: number | null
          provider?: string
          provider_data?: Json
          purchase_token?: string | null
          reference?: string
          referral_friends?: number
          refunded_at?: string | null
          source?: string
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id?: string | null
          verified_at?: string | null
          xp_pack?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_code_id_fkey"
            columns: ["code_id"]
            isOneToOne: false
            referencedRelation: "promo_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_entitlement_id_fkey"
            columns: ["entitlement_id"]
            isOneToOne: false
            referencedRelation: "entitlements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
        ]
      }
      plans: {
        Row: {
          play_product_id_fee: string | null
          code: string
          description: string | null
          duration_days: number | null
          ends_on: string | null
          id: number
          is_active: boolean
          name: string
          play_product_id: string | null
          price_kobo: number
          sort: number
        }
        Insert: {
          play_product_id_fee?: string | null
          code: string
          description?: string | null
          duration_days?: number | null
          ends_on?: string | null
          id?: never
          is_active?: boolean
          name: string
          play_product_id?: string | null
          price_kobo: number
          sort?: number
        }
        Update: {
          play_product_id_fee?: string | null
          code?: string
          description?: string | null
          duration_days?: number | null
          ends_on?: string | null
          id?: never
          is_active?: boolean
          name?: string
          play_product_id?: string | null
          price_kobo?: number
          sort?: number
        }
        Relationships: []
      }
      prize_claims: {
        Row: {
          account_name: string
          account_number: string
          admin_note: string | null
          adult: boolean
          amount: number
          bank_code: string | null
          bank_name: string
          created_at: string
          entry_id: string
          guardian_name: string | null
          guardian_phone: string | null
          id: string
          paid_at: string | null
          paid_by: string | null
          payout_at: string | null
          payout_by: string | null
          payout_error: string | null
          payout_ref: string | null
          payout_status: string
          recipient_code: string | null
          status: string
          transfer_code: string | null
          user_id: string
          verified_name: string | null
        }
        Insert: {
          account_name: string
          account_number: string
          admin_note?: string | null
          adult: boolean
          amount: number
          bank_code?: string | null
          bank_name: string
          created_at?: string
          entry_id: string
          guardian_name?: string | null
          guardian_phone?: string | null
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          payout_at?: string | null
          payout_by?: string | null
          payout_error?: string | null
          payout_ref?: string | null
          payout_status?: string
          recipient_code?: string | null
          status?: string
          transfer_code?: string | null
          user_id: string
          verified_name?: string | null
        }
        Update: {
          account_name?: string
          account_number?: string
          admin_note?: string | null
          adult?: boolean
          amount?: number
          bank_code?: string | null
          bank_name?: string
          created_at?: string
          entry_id?: string
          guardian_name?: string | null
          guardian_phone?: string | null
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          payout_at?: string | null
          payout_by?: string | null
          payout_error?: string | null
          payout_ref?: string | null
          payout_status?: string
          recipient_code?: string | null
          status?: string
          transfer_code?: string | null
          user_id?: string
          verified_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "prize_claims_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: true
            referencedRelation: "challenge_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      risk_events: {
        Row: {
          created_at: string
          detail: string | null
          dismissed_at: string | null
          dismissed_by: string | null
          id: number
          kind: string
          points: number
          ref: string
          user_id: string
        }
        Insert: {
          created_at?: string
          detail?: string | null
          dismissed_at?: string | null
          dismissed_by?: string | null
          id?: number
          kind: string
          points: number
          ref: string
          user_id: string
        }
        Update: {
          created_at?: string
          detail?: string | null
          dismissed_at?: string | null
          dismissed_by?: string | null
          id?: number
          kind?: string
          points?: number
          ref?: string
          user_id?: string
        }
        Relationships: []
      }
      tutor_messages: {
        Row: {
          attachment_path: string | null
          body: string
          created_at: string
          from_staff: boolean
          id: number
          kind: string
          meta: Json | null
          read_at: string | null
          ref: Json | null
          request_id: string
          sender_id: string | null
          sender_role: string
        }
        Insert: {
          attachment_path?: string | null
          body: string
          created_at?: string
          from_staff?: boolean
          id?: number
          kind?: string
          meta?: Json | null
          read_at?: string | null
          ref?: Json | null
          request_id: string
          sender_id?: string | null
          sender_role?: string
        }
        Update: {
          attachment_path?: string | null
          body?: string
          created_at?: string
          from_staff?: boolean
          id?: number
          kind?: string
          meta?: Json | null
          read_at?: string | null
          ref?: Json | null
          request_id?: string
          sender_id?: string | null
          sender_role?: string
        }
        Relationships: []
      }
      tutor_plans: {
        Row: {
          active: boolean
          created_at: string
          days: number
          description: string | null
          id: string
          name: string
          play_product_id: string | null
          price_kobo: number
          sessions: number | null
          sort: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          days?: number
          description?: string | null
          id?: string
          name: string
          play_product_id?: string | null
          price_kobo: number
          sessions?: number | null
          sort?: number
        }
        Update: {
          active?: boolean
          created_at?: string
          days?: number
          description?: string | null
          id?: string
          name?: string
          play_product_id?: string | null
          price_kobo?: number
          sessions?: number | null
          sort?: number
        }
        Relationships: []
      }
      tutor_requests: {
        Row: {
          assigned_at: string | null
          created_at: string
          custom_days: number | null
          custom_note: string | null
          custom_price_kobo: number | null
          goals: string
          id: string
          level: string
          paid_at: string | null
          plan_id: string | null
          status: string
          subject_id: number | null
          times: string | null
          tutor_emailed_at: string | null
          tutor_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          assigned_at?: string | null
          created_at?: string
          custom_days?: number | null
          custom_note?: string | null
          custom_price_kobo?: number | null
          goals: string
          id?: string
          level: string
          paid_at?: string | null
          plan_id?: string | null
          status?: string
          subject_id?: number | null
          times?: string | null
          tutor_emailed_at?: string | null
          tutor_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          assigned_at?: string | null
          created_at?: string
          custom_days?: number | null
          custom_note?: string | null
          custom_price_kobo?: number | null
          goals?: string
          id?: string
          level?: string
          paid_at?: string | null
          plan_id?: string | null
          status?: string
          subject_id?: number | null
          times?: string | null
          tutor_emailed_at?: string | null
          tutor_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tutor_subscriptions: {
        Row: {
          ends_at: string
          id: string
          payment_id: string | null
          plan_id: string | null
          request_id: string | null
          starts_at: string
          user_id: string
        }
        Insert: {
          ends_at: string
          id?: string
          payment_id?: string | null
          plan_id?: string | null
          request_id?: string | null
          starts_at?: string
          user_id: string
        }
        Update: {
          ends_at?: string
          id?: string
          payment_id?: string | null
          plan_id?: string
          request_id?: string | null
          starts_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tutors: {
        Row: {
          active: boolean
          bio: string | null
          created_at: string
          id: string
          last_seen_at: string | null
          name: string
          phone: string | null
          photo_path: string | null
          subjects: string | null
          user_id: string | null
          whatsapp: string | null
        }
        Insert: {
          active?: boolean
          bio?: string | null
          created_at?: string
          id?: string
          last_seen_at?: string | null
          name: string
          phone?: string | null
          photo_path?: string | null
          subjects?: string | null
          user_id?: string | null
          whatsapp?: string | null
        }
        Update: {
          active?: boolean
          bio?: string | null
          created_at?: string
          id?: string
          last_seen_at?: string | null
          name?: string
          phone?: string | null
          photo_path?: string | null
          subjects?: string | null
          user_id?: string | null
          whatsapp?: string | null
        }
        Relationships: []
      }
      user_badges: {
        Row: {
          backfill: boolean
          badge_id: number
          days_given: number
          reached_at: string
          seen_at: string | null
          tier: number
          user_id: string
          xp_given: number
        }
        Insert: {
          backfill?: boolean
          badge_id: number
          days_given?: number
          reached_at?: string
          seen_at?: string | null
          tier: number
          user_id: string
          xp_given?: number
        }
        Update: {
          backfill?: boolean
          badge_id?: number
          days_given?: number
          reached_at?: string
          seen_at?: string | null
          tier?: number
          user_id?: string
          xp_given?: number
        }
        Relationships: []
      }
      web_handoffs: {
        Row: { code_hash: string; created_at: string; expires_at: string; ip_hash: string | null; plan: string | null; used_at: string | null; user_id: string }
        Insert: { code_hash: string; created_at?: string; expires_at?: string; ip_hash?: string | null; plan?: string | null; used_at?: string | null; user_id: string }
        Update: { code_hash?: string; created_at?: string; expires_at?: string; ip_hash?: string | null; plan?: string | null; used_at?: string | null; user_id?: string }
        Relationships: []
      }
      guardian_consents: {
        Row: {
          child_birth_year: number
          created_at: string
          guardian_email: string
          method: string
          policy_version: string
          send_count: number
          sent_at: string | null
          token_hash: string
          updated_at: string
          user_id: string
          withdrawn_at: string | null
        }
        Insert: {
          child_birth_year: number
          created_at?: string
          guardian_email: string
          method?: string
          policy_version: string
          send_count?: number
          sent_at?: string | null
          token_hash: string
          updated_at?: string
          user_id: string
          withdrawn_at?: string | null
        }
        Update: {
          child_birth_year?: number
          created_at?: string
          guardian_email?: string
          method?: string
          policy_version?: string
          send_count?: number
          sent_at?: string | null
          token_hash?: string
          updated_at?: string
          user_id?: string
          withdrawn_at?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_path: string | null
          ban_reason: string | null
          banned_at: string | null
          ads_consent: boolean
          ads_consent_at: string | null
          birth_year: number | null
          career_id: number | null
          paused_at: string | null
          paused_reason: string | null
          created_at: string
          full_name: string | null
          hide_on_leaderboard: boolean
          id: string
          jamb_subjects: string[]
          phone: string | null
          referral_code: string | null
          school: string | null
          show_photo_on_leaderboard: boolean
          state: string | null
          streak_freezes: number
          streak_seen: string | null
          target_exams: string[]
          target_score: number | null
          updated_at: string
          xp_bought: number
          xp_earned: number
        }
        Insert: {
          avatar_path?: string | null
          ban_reason?: string | null
          banned_at?: string | null
          ads_consent?: boolean
          ads_consent_at?: string | null
          birth_year?: number | null
          career_id?: number | null
          paused_at?: string | null
          paused_reason?: string | null
          created_at?: string
          full_name?: string | null
          hide_on_leaderboard?: boolean
          id: string
          jamb_subjects?: string[]
          phone?: string | null
          referral_code?: string | null
          school?: string | null
          show_photo_on_leaderboard?: boolean
          state?: string | null
          streak_freezes?: number
          streak_seen?: string | null
          target_exams?: string[]
          target_score?: number | null
          updated_at?: string
          xp_bought?: number
          xp_earned?: number
        }
        Update: {
          avatar_path?: string | null
          ban_reason?: string | null
          banned_at?: string | null
          ads_consent?: boolean
          ads_consent_at?: string | null
          birth_year?: number | null
          career_id?: number | null
          paused_at?: string | null
          paused_reason?: string | null
          created_at?: string
          full_name?: string | null
          hide_on_leaderboard?: boolean
          id?: string
          jamb_subjects?: string[]
          phone?: string | null
          referral_code?: string | null
          school?: string | null
          show_photo_on_leaderboard?: boolean
          state?: string | null
          streak_freezes?: number
          streak_seen?: string | null
          target_exams?: string[]
          target_score?: number | null
          updated_at?: string
          xp_bought?: number
          xp_earned?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_career_id_fkey"
            columns: ["career_id"]
            isOneToOne: false
            referencedRelation: "careers"
            referencedColumns: ["id"]
          },
        ]
      }
      promo_codes: {
        Row: {
          batch_id: string | null
          code: string
          created_at: string
          created_by: string | null
          deleted_at: string | null
          ends_at: string | null
          id: string
          kind: Database["public"]["Enums"]["promo_kind"]
          max_uses: number | null
          new_only: boolean
          note: string | null
          paused: boolean
          plan_ids: number[]
          starts_at: string
          updated_at: string
          used_count: number
          value: number
        }
        Insert: {
          batch_id?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          ends_at?: string | null
          id?: string
          kind: Database["public"]["Enums"]["promo_kind"]
          max_uses?: number | null
          new_only?: boolean
          note?: string | null
          paused?: boolean
          plan_ids?: number[]
          starts_at?: string
          updated_at?: string
          used_count?: number
          value: number
        }
        Update: {
          batch_id?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          ends_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["promo_kind"]
          max_uses?: number | null
          new_only?: boolean
          note?: string | null
          paused?: boolean
          plan_ids?: number[]
          starts_at?: string
          updated_at?: string
          used_count?: number
          value?: number
        }
        Relationships: []
      }
      promo_redemptions: {
        Row: {
          code_id: string
          created_at: string
          days: number | null
          discount_kobo: number | null
          entitlement_id: string | null
          id: string
          payment_id: string | null
          user_id: string
        }
        Insert: {
          code_id: string
          created_at?: string
          days?: number | null
          discount_kobo?: number | null
          entitlement_id?: string | null
          id?: string
          payment_id?: string | null
          user_id: string
        }
        Update: {
          code_id?: string
          created_at?: string
          days?: number | null
          discount_kobo?: number | null
          entitlement_id?: string | null
          id?: string
          payment_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promo_redemptions_code_id_fkey"
            columns: ["code_id"]
            isOneToOne: false
            referencedRelation: "promo_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promo_redemptions_entitlement_id_fkey"
            columns: ["entitlement_id"]
            isOneToOne: false
            referencedRelation: "entitlements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promo_redemptions_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      push_tokens: {
        Row: {
          app_version: string | null
          created_at: string
          last_seen: string
          platform: string
          token: string
          user_id: string
        }
        Insert: {
          app_version?: string | null
          created_at?: string
          last_seen?: string
          platform?: string
          token: string
          user_id?: string
        }
        Update: {
          app_version?: string | null
          created_at?: string
          last_seen?: string
          platform?: string
          token?: string
          user_id?: string
        }
        Relationships: []
      }
      qotd: {
        Row: {
          created_at: string
          created_by: string | null
          custom_answer: string | null
          custom_body: string | null
          custom_explanation: string | null
          custom_options: Json | null
          custom_subject: string | null
          day: string
          id: string
          question_id: string | null
          source: string
          subject_id: number | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          custom_answer?: string | null
          custom_body?: string | null
          custom_explanation?: string | null
          custom_options?: Json | null
          custom_subject?: string | null
          day: string
          id?: string
          question_id?: string | null
          source?: string
          subject_id?: number | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          custom_answer?: string | null
          custom_body?: string | null
          custom_explanation?: string | null
          custom_options?: Json | null
          custom_subject?: string | null
          day?: string
          id?: string
          question_id?: string | null
          source?: string
          subject_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "qotd_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "qotd_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      qotd_answers: {
        Row: {
          answered_at: string
          choice: string
          correct: boolean
          day: string
          qotd_id: string
          user_id: string
        }
        Insert: {
          answered_at?: string
          choice: string
          correct: boolean
          day: string
          qotd_id: string
          user_id: string
        }
        Update: {
          answered_at?: string
          choice?: string
          correct?: boolean
          day?: string
          qotd_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "qotd_answers_qotd_id_fkey"
            columns: ["qotd_id"]
            isOneToOne: false
            referencedRelation: "qotd"
            referencedColumns: ["id"]
          },
        ]
      }
      questions: {
        Row: {
          answer: string
          body: string
          content_hash: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          difficulty: Database["public"]["Enums"]["difficulty"] | null
          exam_id: number
          explanation: string | null
          id: string
          image_path: string | null
          import_batch_id: string | null
          number: number | null
          options: Json
          passage_id: string | null
          section: string | null
          section_source: string | null
          source: string
          paused_by_switch: boolean
          status: Database["public"]["Enums"]["content_status"]
          subject_id: number
          topic_id: number | null
          updated_at: string
          updated_by: string | null
          year: number
        }
        Insert: {
          answer: string
          body: string
          content_hash?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          difficulty?: Database["public"]["Enums"]["difficulty"] | null
          exam_id: number
          explanation?: string | null
          id?: string
          image_path?: string | null
          import_batch_id?: string | null
          number?: number | null
          options: Json
          passage_id?: string | null
          section?: string | null
          section_source?: string | null
          source?: string
          paused_by_switch?: boolean
          status?: Database["public"]["Enums"]["content_status"]
          subject_id: number
          topic_id?: number | null
          updated_at?: string
          updated_by?: string | null
          year: number
        }
        Update: {
          answer?: string
          body?: string
          content_hash?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          difficulty?: Database["public"]["Enums"]["difficulty"] | null
          exam_id?: number
          explanation?: string | null
          id?: string
          image_path?: string | null
          import_batch_id?: string | null
          number?: number | null
          options?: Json
          passage_id?: string | null
          section?: string | null
          section_source?: string | null
          source?: string
          paused_by_switch?: boolean
          status?: Database["public"]["Enums"]["content_status"]
          subject_id?: number
          topic_id?: number | null
          updated_at?: string
          updated_by?: string | null
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "questions_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_passage_id_fkey"
            columns: ["passage_id"]
            isOneToOne: false
            referencedRelation: "passages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_rewards: {
        Row: {
          account_name: string | null
          account_number: string | null
          admin_note: string | null
          amount: number
          bank_name: string | null
          claimed_at: string | null
          created_at: string
          id: string
          milestone: number
          paid_at: string | null
          paid_by: string | null
          receipt_path: string | null
          status: string
          user_id: string
        }
        Insert: {
          account_name?: string | null
          account_number?: string | null
          admin_note?: string | null
          amount: number
          bank_name?: string | null
          claimed_at?: string | null
          created_at?: string
          id?: string
          milestone: number
          paid_at?: string | null
          paid_by?: string | null
          receipt_path?: string | null
          status?: string
          user_id: string
        }
        Update: {
          account_name?: string | null
          account_number?: string | null
          admin_note?: string | null
          amount?: number
          bank_name?: string | null
          claimed_at?: string | null
          created_at?: string
          id?: string
          milestone?: number
          paid_at?: string | null
          paid_by?: string | null
          receipt_path?: string | null
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referral_rewards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          code: string | null
          counted_at: string | null
          created_at: string
          friend: string
          id: string
          reason: string | null
          referrer: string
          spent_payment: string | null
          status: string
        }
        Insert: {
          code?: string | null
          counted_at?: string | null
          created_at?: string
          friend: string
          id?: string
          reason?: string | null
          referrer: string
          spent_payment?: string | null
          status?: string
        }
        Update: {
          code?: string | null
          counted_at?: string | null
          created_at?: string
          friend?: string
          id?: string
          reason?: string | null
          referrer?: string
          spent_payment?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "referrals_friend_fkey"
            columns: ["friend"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_referrer_fkey"
            columns: ["referrer"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_spent_payment_fkey"
            columns: ["spent_payment"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      staff: {
        Row: {
          created_at: string
          created_by: string | null
          role: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          role: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          role?: Database["public"]["Enums"]["staff_role"]
          user_id?: string
        }
        Relationships: []
      }
      streak_saves: {
        Row: {
          created_at: string
          day: string
          kind: string
          user_id: string
        }
        Insert: {
          created_at?: string
          day: string
          kind: string
          user_id: string
        }
        Update: {
          created_at?: string
          day?: string
          kind?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "streak_saves_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      study_items: {
        Row: {
          access: string | null
          ad_count: number | null
          ad_hours: number | null
          body: string | null
          created_at: string
          created_by: string | null
          data: Json
          deleted_at: string | null
          exam_id: number | null
          files: Json
          id: string
          is_free: boolean
          kind: string
          pay_premium: boolean | null
          price_kobo: number | null
          question_id: string | null
          sort: number
          status: Database["public"]["Enums"]["content_status"]
          subject_id: number | null
          subtitle: string | null
          title: string
          topic_id: number | null
          updated_at: string
          updated_by: string | null
          year: number | null
        }
        Insert: {
          access?: string | null
          ad_count?: number | null
          ad_hours?: number | null
          body?: string | null
          created_at?: string
          created_by?: string | null
          data?: Json
          deleted_at?: string | null
          exam_id?: number | null
          files?: Json
          id?: string
          is_free?: boolean
          kind: string
          pay_premium?: boolean | null
          price_kobo?: number | null
          question_id?: string | null
          sort?: number
          status?: Database["public"]["Enums"]["content_status"]
          subject_id?: number | null
          subtitle?: string | null
          title: string
          topic_id?: number | null
          updated_at?: string
          updated_by?: string | null
          year?: number | null
        }
        Update: {
          access?: string | null
          ad_count?: number | null
          ad_hours?: number | null
          body?: string | null
          created_at?: string
          created_by?: string | null
          data?: Json
          deleted_at?: string | null
          exam_id?: number | null
          files?: Json
          id?: string
          is_free?: boolean
          kind?: string
          pay_premium?: boolean | null
          price_kobo?: number | null
          question_id?: string | null
          sort?: number
          status?: Database["public"]["Enums"]["content_status"]
          subject_id?: number | null
          subtitle?: string | null
          title?: string
          topic_id?: number | null
          updated_at?: string
          updated_by?: string | null
          year?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "study_items_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_items_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_items_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_items_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      study_plans: {
        Row: {
          chat_id: string | null
          created_at: string
          days: Json
          done: number[]
          ended_at: string | null
          id: string
          reminders: boolean
          starts_on: string
          title: string
          user_id: string
        }
        Insert: {
          chat_id?: string | null
          created_at?: string
          days: Json
          done?: number[]
          ended_at?: string | null
          id?: string
          reminders?: boolean
          starts_on: string
          title?: string
          user_id: string
        }
        Update: {
          chat_id?: string | null
          created_at?: string
          days?: Json
          done?: number[]
          ended_at?: string | null
          id?: string
          reminders?: boolean
          starts_on?: string
          title?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "study_plans_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "ai_chats"
            referencedColumns: ["id"]
          },
        ]
      }
      study_progress: {
        Row: {
          item_id: string
          position: Json
          progress: number
          updated_at: string
          user_id: string
        }
        Insert: {
          item_id: string
          position?: Json
          progress?: number
          updated_at?: string
          user_id?: string
        }
        Update: {
          item_id?: string
          position?: Json
          progress?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "study_progress_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "study_items"
            referencedColumns: ["id"]
          },
        ]
      }
      subjects: {
        Row: {
          code: string
          id: number
          name: string
          sort: number
        }
        Insert: {
          code: string
          id?: never
          name: string
          sort?: number
        }
        Update: {
          code?: string
          id?: never
          name?: string
          sort?: number
        }
        Relationships: []
      }
      topics: {
        Row: {
          id: number
          name: string
          parent_id: number | null
          sort: number
          subject_id: number
        }
        Insert: {
          id?: never
          name: string
          parent_id?: number | null
          sort?: number
          subject_id: number
        }
        Update: {
          id?: never
          name?: string
          parent_id?: number | null
          sort?: number
          subject_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "topics_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "topics_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      winners_wall: {
        Row: {
          amount: number
          challenge_title: string
          claim_id: string | null
          created_at: string
          created_by: string | null
          id: string
          name: string
          note: string | null
          place: string
          published: boolean
          receipt_path: string | null
          state: string | null
        }
        Insert: {
          amount: number
          challenge_title: string
          claim_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          note?: string | null
          place: string
          published?: boolean
          receipt_path?: string | null
          state?: string | null
        }
        Update: {
          amount?: number
          challenge_title?: string
          claim_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          note?: string | null
          place?: string
          published?: boolean
          receipt_path?: string | null
          state?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "winners_wall_claim_id_fkey"
            columns: ["claim_id"]
            isOneToOne: true
            referencedRelation: "prize_claims"
            referencedColumns: ["id"]
          },
        ]
      }
      xp_ledger: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          id: number
          key: string | null
          kind: string
          note: string | null
          reason: string
          ref: string | null
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          id?: never
          key?: string | null
          kind: string
          note?: string | null
          reason: string
          ref?: string | null
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          id?: never
          key?: string | null
          kind?: string
          note?: string | null
          reason?: string
          ref?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "xp_ledger_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      year_access: {
        Row: {
          access: string
          ad_count: number | null
          ad_hours: number | null
          exam_id: number
          pay_premium: boolean | null
          price_kobo: number | null
          updated_at: string
          year: number
        }
        Insert: {
          access: string
          ad_count?: number | null
          ad_hours?: number | null
          exam_id: number
          pay_premium?: boolean | null
          price_kobo?: number | null
          updated_at?: string
          year: number
        }
        Update: {
          access?: string
          ad_count?: number | null
          ad_hours?: number | null
          exam_id?: number
          pay_premium?: boolean | null
          price_kobo?: number | null
          updated_at?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "year_access_exam_id_fkey"
            columns: ["exam_id"]
            isOneToOne: false
            referencedRelation: "exam_bodies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      ad_reward_grant: {
        Args: { p_nonce: string; p_tx: string; p_unit: string; p_user: string }
        Returns: Json
      }
      ad_reward_start: {
        Args: { p_kind: string; p_ref?: string }
        Returns: Json
      }
      ad_reward_status: {
        Args: { p_nonce: string; p_test_claim?: boolean }
        Returns: Json
      }
      ad_year_suggest: { Args: never; Returns: Json }
      admin_ad_campaign_delete: { Args: { p_id: string }; Returns: Json }
      admin_ad_campaign_report: { Args: { p_id: string }; Returns: Json }
      admin_ad_campaign_save: { Args: { p: Json }; Returns: Json }
      admin_ad_campaigns: { Args: never; Returns: Json }
      admin_ads_report: { Args: { p_days?: number }; Returns: Json }
      admin_ads_save: { Args: { p_value: Json }; Returns: Json }
      admin_ai_health: { Args: never; Returns: Json }
      admin_ai_safety_decide: {
        Args: { p_decision: string; p_note?: string; p_user: string }
        Returns: Json
      }
      admin_ai_safety_list: { Args: never; Returns: Json }
      admin_archive_codes: {
        Args: { p_batch: string; p_id: string }
        Returns: number
      }
      admin_badge_counts: { Args: never; Returns: { badge_id: number; tier: number; holders: number }[] }
      admin_ban: {
        Args: {
          p_banned: boolean
          p_linked?: boolean
          p_reason?: string
          p_user: string
        }
        Returns: Json
      }
      admin_ban_appeal: {
        Args: { p_accept: boolean; p_appeal: string; p_note?: string }
        Returns: undefined
      }
      admin_ban_device: {
        Args: { p_hash: string; p_reason: string }
        Returns: Json
      }
      admin_batch_codes: {
        Args: { p_batch: string }
        Returns: {
          code: string
          used: number
        }[]
      }
      admin_challenge_add_random: {
        Args: { p_count: number; p_id: string; p_subjects: number[] }
        Returns: Json
      }
      admin_challenge_appeal: {
        Args: { p_accept: boolean; p_appeal: string; p_note?: string }
        Returns: Json
      }
      admin_challenge_appeals: { Args: never; Returns: Json }
      admin_challenge_close: { Args: { p_id: string }; Returns: Json }
      admin_challenge_copy: {
        Args: { p_id: string; p_starts: string }
        Returns: string
      }
      admin_challenge_entries: { Args: { p_id: string }; Returns: Json }
      admin_challenge_live: { Args: { p_id: string }; Returns: Json }
      admin_challenge_review: {
        Args: { p_decision: string; p_entry: string }
        Returns: Json
      }
      admin_challenge_set_level: {
        Args: { p_level: string; p_question: string }
        Returns: undefined
      }
      admin_challenge_set_review: {
        Args: { p_id: string; p_on: boolean }
        Returns: undefined
      }
      admin_class_students: { Args: { p_class: string }; Returns: Json }
      admin_class_submissions: { Args: { p_class: string }; Returns: Json }
      admin_codes: { Args: never; Returns: Json }
      admin_community_counts: { Args: never; Returns: Json }
      admin_content_access: { Args: never; Returns: Json }
      admin_content_access_save: { Args: { p_defaults: Json }; Returns: Json }
      admin_create_code_batch: {
        Args: {
          p_count: number
          p_ends: string
          p_kind: Database["public"]["Enums"]["promo_kind"]
          p_new_only?: boolean
          p_note: string
          p_plan_ids: number[]
          p_prefix: string
          p_starts: string
          p_value: number
        }
        Returns: Json
      }
      admin_dashboard: { Args: never; Returns: Json }
      admin_device_allow: {
        Args: { p_allowed: boolean; p_hash: string; p_user: string }
        Returns: undefined
      }
      admin_device_appeal: {
        Args: { p_accept: boolean; p_id: string; p_note?: string }
        Returns: Json
      }
      admin_fraud: { Args: never; Returns: Json }
      admin_games_stats: { Args: never; Returns: Json }
      admin_leaderboard_held: { Args: { p_season?: number }; Returns: Json }
      admin_leaderboard_recent: { Args: { p_limit?: number }; Returns: Json }
      admin_list_staff: {
        Args: never
        Returns: {
          created_at: string
          email: string
          full_name: string
          has_2fa: boolean
          last_sign_in_at: string
          role: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }[]
      }
      admin_list_users: {
        Args: { p_limit?: number; p_offset?: number; p_search?: string }
        Returns: {
          banned_at: string
          created_at: string
          email: string
          full_name: string
          id: string
          is_premium: boolean
          last_sign_in_at: string
          phone: string
          premium_until: string
          staff_role: Database["public"]["Enums"]["staff_role"]
          state: string
          total: number
        }[]
      }
      admin_news_comments: { Args: { p_filter?: string }; Returns: { id: string; post_id: string; post_title: string; user_id: string; name: string; body: string; created_at: string; reports: number; hidden_at: string | null; hidden_reason: string | null; reviewed_at: string | null }[] }
      admin_notifications: { Args: { p_limit?: number }; Returns: Json }
      admin_pause_codes: {
        Args: { p_id: string; p_paused: boolean }
        Returns: number
      }
      admin_payment: { Args: { p_id: string }; Returns: Json }
      admin_payments: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_provider?: string
          p_q?: string
          p_status?: string
        }
        Returns: Json
      }
      admin_prize_claims: { Args: never; Returns: Json }
      admin_qotd_candidates: {
        Args: { p_limit?: number; p_search?: string; p_subject?: number }
        Returns: Json
      }
      admin_qotd_days: { Args: { p_from: string; p_to: string }; Returns: Json }
      admin_qotd_stats: { Args: { p_days?: number }; Returns: Json }
      admin_question_is_free: { Args: { p_id: string }; Returns: boolean }
      admin_referral_paid: {
        Args: { p_note?: string; p_receipt?: string; p_reward: string }
        Returns: undefined
      }
      admin_referral_settings: { Args: { p: Json }; Returns: undefined }
      admin_referrals: { Args: never; Returns: Json }
      admin_safety_clear: { Args: { p_user: string }; Returns: undefined }
      admin_safety_list: { Args: { p_limit?: number }; Returns: Json }
      admin_safety_run: { Args: never; Returns: Json }
      admin_set_ai_key: {
        Args: { p_key: string; p_provider: string }
        Returns: string
      }
      admin_set_ban: {
        Args: { p_banned: boolean; p_reason?: string; p_user: string }
        Returns: undefined
      }
      admin_tutor_assign: { Args: { p_request: string; p_tutor: string }; Returns: Json }
      admin_tutor_close: { Args: { p_request: string }; Returns: Json }
      admin_tutor_quote: { Args: { p_request: string; p_price_kobo: number; p_days: number }; Returns: Json }
      admin_tutor_requests: { Args: { p_status?: string }; Returns: Json }
      admin_unban_device: { Args: { p_hash: string }; Returns: Json }
      admin_update_codes: {
        Args: {
          p_ends: string
          p_id: string
          p_max_uses: number
          p_new_only: boolean
          p_note: string
          p_plan_ids: number[]
          p_starts: string
          p_value: number
        }
        Returns: number
      }
      admin_user_detail: { Args: { p_user: string }; Returns: Json }
      admin_welcome: { Args: never; Returns: Json }
      admin_welcome_save: { Args: { p: Json }; Returns: Json }
      admin_xp_adjust: {
        Args: { p_amount: number; p_reason: string; p_user: string }
        Returns: Json
      }
      admin_xp_overview: { Args: never; Returns: Json }
      admin_xp_settings: { Args: { p: Json }; Returns: undefined }
      admin_xp_user: { Args: { p_query: string }; Returns: Json }
      admin_year_access_save: {
        Args: {
          p_access: string
          p_ads: number
          p_exam: number
          p_hours: number
          p_premium_pays: boolean
          p_price_kobo: number
          p_year: number
        }
        Returns: Json
      }
      admin_year_counts: {
        Args: { p_exam: number }
        Returns: {
          published: number
          subject_id: number
          total: number
          year: number
        }[]
      }
      ads_config: { Args: never; Returns: Json }
      ads_log: { Args: { p_events: Json }; Returns: undefined }
      ai_block_status: { Args: { p_uid: string }; Returns: Json }
      ai_chunk_sources: {
        Args: { p_source: string }
        Returns: {
          indexed_at: string
          source_id: string
        }[]
      }
      ai_config: { Args: never; Returns: Json }
      ai_find_notes: {
        Args: { p_q: string; p_subject?: number; p_uid: string }
        Returns: Json
      }
      ai_flag: {
        Args: { p_message: string; p_reason: string }
        Returns: undefined
      }
      ai_match: {
        Args: { p_count?: number; p_embedding: string; p_subject?: number }
        Returns: {
          content: string
          similarity: number
          title: string
        }[]
      }
      ai_match_for: {
        Args: {
          p_count?: number
          p_embedding: string
          p_subject?: number
          p_uid: string
        }
        Returns: {
          content: string
          item_id: string
          similarity: number
          title: string
        }[]
      }
      ai_most_missed: {
        Args: { p_limit?: number; p_subjects?: number[] }
        Returns: Json
      }
      ai_nudge_candidates: { Args: { p_limit?: number }; Returns: Json }
      ai_pick: {
        Args: {
          p_count?: number
          p_difficulty?: string
          p_for?: string
          p_subject: number
          p_topic?: string
        }
        Returns: Json
      }
      ai_pick2: {
        Args: {
          p_count?: number
          p_difficulty?: string
          p_exam?: string
          p_for?: string
          p_subject: number
          p_topic?: string
          p_year?: number
        }
        Returns: Json
      }
      ai_provider_key: { Args: { p_provider: string }; Returns: string }
      ai_question_for_me: { Args: { p_id: string }; Returns: Json }
      ai_quiz_check: { Args: { p_choice: string; p_id: string }; Returns: Json }
      ai_quota: { Args: never; Returns: Json }
      ai_react: {
        Args: { p_message: string; p_reaction: string }
        Returns: undefined
      }
      ai_read_note: {
        Args: { p_q: string; p_subject?: number; p_uid: string }
        Returns: Json
      }
      ai_refund: { Args: { p_uid: string }; Returns: undefined }
      ai_strike: {
        Args: { p_kind: string; p_text: string; p_uid: string }
        Returns: Json
      }
      ai_student_context: { Args: { p_uid: string }; Returns: Json }
      ai_take: { Args: { p_uid: string }; Returns: number }
      ai_weak_topics: {
        Args: { p_limit?: number; p_uid: string }
        Returns: Json
      }
      am_content_editor: { Args: never; Returns: boolean }
      am_money_admin: { Args: never; Returns: boolean }
      am_notifier: { Args: never; Returns: boolean }
      arena_answer: { Args: { p_arena: string; p_index: number; p_choice: string }; Returns: Json }
      arena_join: { Args: { p_arena: string }; Returns: Json }
      arena_state: { Args: { p_arena: string }; Returns: Json }
      arenas_list: { Args: never; Returns: Json }
      auth_user_status: { Args: { p_email: string }; Returns: string }
      badges_check: { Args: never; Returns: Json }
      badges_seen: { Args: { p_badges: number[] }; Returns: undefined }
      ban_appeal: { Args: { p_reason: string }; Returns: Json }
      can_upload_images: { Args: never; Returns: boolean }
      can_view_ad_file: { Args: { p_key: string }; Returns: boolean }
      can_view_avatar: { Args: { p_key: string }; Returns: boolean }
      can_view_challenge_image: { Args: { p_key: string }; Returns: boolean }
      can_view_community_image: { Args: { p_key: string }; Returns: boolean }
      can_view_note_image: { Args: { p_key: string }; Returns: boolean }
      can_view_question_image: { Args: { p_key: string }; Returns: boolean }
      can_view_study_file: { Args: { p_key: string }; Returns: boolean }
      can_view_tutor_file: { Args: { p_key: string }; Returns: boolean }
      cbt_paper: {
        Args: {
          p_count?: number
          p_exam: number
          p_subject: number
          p_year?: number
        }
        Returns: Json
      }
      challenge_answer: {
        Args: { p_choice: string; p_entry: string; p_question: string }
        Returns: Json
      }
      challenge_appeal: {
        Args: { p_id: string; p_image?: string; p_reason: string }
        Returns: Json
      }
      challenge_detail: { Args: { p_id: string }; Returns: Json }
      challenge_exit: {
        Args: { p_entry: string; p_reason?: string }
        Returns: Json
      }
      challenge_make_invites: {
        Args: { p_id: string; p_labels: string[] }
        Returns: Json
      }
      challenge_report: {
        Args: { p_entry: string; p_what: string }
        Returns: undefined
      }
      challenge_result: { Args: { p_id: string }; Returns: Json }
      challenge_review: { Args: { p_id: string }; Returns: Json }
      challenge_set_code: {
        Args: { p_code: string; p_id: string }
        Returns: undefined
      }
      challenge_start: {
        Args: { p_device?: string; p_device_flags?: string[]; p_id: string }
        Returns: Json
      }
      challenge_unlock: {
        Args: { p_code: string; p_id: string }
        Returns: Json
      }
      challenges_list: { Args: never; Returns: Json }
      class_join: { Args: { p_class: string }; Returns: Json }
      class_recording: { Args: { p_class: string }; Returns: Json }
      class_register: { Args: { p_class: string }; Returns: Json }
      class_submit: { Args: { p_assignment: string; p_answer: string }; Returns: Json }
      classes_list: { Args: never; Returns: Json }
      community_ai_answer: { Args: { p_post: string; p_body: string }; Returns: Json }
      community_block: { Args: { p_user: string }; Returns: Json }
      community_comment_add: { Args: { p_post: string; p_body: string }; Returns: Json }
      community_comment_delete: { Args: { p_id: number }; Returns: Json }
      community_decide: { Args: { p_kind: string; p_id: string; p_ok: boolean; p_reason: string }; Returns: Json }
      community_feed: { Args: { p_tab?: string; p_subject?: number; p_offset?: number }; Returns: Json }
      community_follow: { Args: { p_user: string }; Returns: Json }
      community_like: { Args: { p_id: string }; Returns: Json }
      community_pending: { Args: { p_limit?: number }; Returns: Json }
      community_post_create: { Args: { p_body: string; p_image?: string; p_subject?: number }; Returns: Json }
      community_post_delete: { Args: { p_id: string }; Returns: Json }
      community_post_get: { Args: { p_id: string }; Returns: Json }
      community_profile: { Args: { p_user: string }; Returns: Json }
      community_report: { Args: { p_kind: string; p_ref: string; p_reason: string }; Returns: Json }
      content_offer: { Args: { p_kind: string; p_ref: string }; Returns: Json }
      content_pay_start: {
        Args: {
          p_kind: string
          p_ref: string
          p_source?: string
          p_uid: string
        }
        Returns: Json
      }
      device_appeal: {
        Args: { p_email: string; p_ids: string[]; p_reason: string }
        Returns: Json
      }
      device_check_in: {
        Args: { p_flags?: string[]; p_ids: string[] }
        Returns: Json
      }
      device_register: { Args: { p_hash: string }; Returns: Json }
      device_status: { Args: { p_ids: string[] }; Returns: Json }
      email_send_allowed: {
        Args: { p_email_hash: string; p_ip_hash: string; p_kind: string }
        Returns: string
      }
      email_sent_last_24h: { Args: never; Returns: number }
      fetch_questions: {
        Args: {
          p_exam: number
          p_limit?: number
          p_mode?: string
          p_offset?: number
          p_subject: number
          p_year: number
        }
        Returns: {
          answer: string
          body: string
          difficulty: Database["public"]["Enums"]["difficulty"]
          explanation: string
          id: string
          image_path: string
          number: number
          options: Json
          passage_body: string
          passage_id: string
          passage_title: string
          topic: string
        }[]
      }
      fetch_questions_by_ids: {
        Args: { p_ids: string[] }
        Returns: {
          answer: string
          body: string
          difficulty: Database["public"]["Enums"]["difficulty"]
          explanation: string
          id: string
          image_path: string
          number: number
          options: Json
          passage_body: string
          passage_id: string
          passage_title: string
          section: string
          topic: string
          year: number
        }[]
      }
      game_answer: { Args: { p_game: string; p_index: number; p_choice: string }; Returns: Json }
      game_create: { Args: { p_mode: string; p_exam: number; p_subject: number }; Returns: Json }
      game_join: { Args: { p_code: string }; Returns: Json }
      game_next: { Args: { p_game: string }; Returns: Json }
      games_mine: { Args: never; Returns: Json }
      house_ad_log: {
        Args: { p_campaign: string; p_click?: boolean; p_placement: string }
        Returns: Json
      }
      house_ads: { Args: never; Returns: Json }
      import_questions: {
        Args: { p_dry_run?: boolean; p_file_name: string; p_rows: Json }
        Returns: Json
      }
      leaderboard: {
        Args: { p_scope?: string; p_season?: number }
        Returns: Json
      }
      leaderboard_challenges: { Args: { p_period?: string; p_offset?: number }; Returns: Json }
      leaderboard_for: {
        Args: {
          p_exam?: string
          p_offset?: number
          p_period?: string
          p_scope?: string
          p_season?: number
          p_subject?: number
        }
        Returns: Json
      }
      leaderboard_winners: { Args: never; Returns: Json }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      mock_analytics: { Args: { p_id: string }; Returns: Json }
      mock_event: {
        Args: { p_entry: string; p_kind: string; p_ms?: number }
        Returns: Json
      }
      mock_gate: { Args: { p_id: string }; Returns: Json }
      mock_result: { Args: { p_id: string }; Returns: Json }
      mock_save: {
        Args: {
          p_choice: string
          p_entry: string
          p_ms?: number
          p_question: string
        }
        Returns: Json
      }
      mock_start: {
        Args: { p_device?: string; p_device_flags?: string[]; p_id: string }
        Returns: Json
      }
      mock_submit: { Args: { p_entry: string }; Returns: Json }
      mock_submit_all: {
        Args: { p_answers?: Json; p_entry: string }
        Returns: Json
      }
      mock_timeline: { Args: { p_entry: string }; Returns: Json }
      my_badges: { Args: never; Returns: Json }
      my_best_jamb: { Args: never; Returns: Json }
      my_class_dashboard: { Args: never; Returns: Json }
      my_dashboard: { Args: never; Returns: Json }
      my_notifications: {
        Args: { p_limit?: number }
        Returns: {
          body: string
          id: string
          link: Json
          read: boolean
          sent_at: string
          title: string
          topic: string
        }[]
      }
      my_open_years: {
        Args: { p_exam?: number }
        Returns: {
          cbt_open: boolean
          exam_id: number
          pq_open: boolean
          subject_id: number
          year: number
        }[]
      }
      my_plan: { Args: never; Returns: Json }
      my_practice_today: { Args: never; Returns: Json }
      my_referrals: { Args: never; Returns: Json }
      my_stats: { Args: never; Returns: Json }
      my_status: { Args: never; Returns: Json }
      my_streak: { Args: never; Returns: Json }
      my_today_plan: { Args: never; Returns: Json }
      my_winnings: { Args: never; Returns: Json }
      my_xp: { Args: never; Returns: Json }
      news_comments_list: { Args: { p_post: string }; Returns: { id: string; name: string; body: string; created_at: string; mine: boolean; hidden: boolean }[] }
      news_meta: { Args: { p_ids: string[] }; Returns: { post_id: string; likes: number; comments: number; liked: boolean; saved: boolean }[] }
      pay_cancel: {
        Args: { p_note?: string; p_reference: string; p_uid: string }
        Returns: Json
      }
      pay_note: {
        Args: {
          p_data?: Json
          p_kind: string
          p_note: string
          p_ok: boolean
          p_provider: string
          p_reference: string
        }
        Returns: undefined
      }
      pay_paystack_result: {
        Args: {
          p_amount_kobo: number
          p_channel: string
          p_currency: string
          p_data: Json
          p_event_key?: string
          p_kind: string
          p_reference: string
          p_requested_kobo?: number
          p_status: string
        }
        Returns: Json
      }
      pay_play_confirm: {
        Args: {
          p_data: Json
          p_order_id: string
          p_product: string
          p_token: string
          p_uid: string
        }
        Returns: Json
      }
      pay_refunded: {
        Args: {
          p_data: Json
          p_event_key: string
          p_provider: string
          p_reference: string
          p_refund_kobo: number
          p_token: string
        }
        Returns: Json
      }
      pay_start: {
        Args: {
          p_code: string
          p_plan: string
          p_source?: string
          p_uid: string
        }
        Returns: Json
      }
      payout_begin: {
        Args: { p_admin: string; p_claim: string }
        Returns: Json
      }
      payout_checked: {
        Args: { p_admin: string; p_claim: string; p_name: string }
        Returns: Json
      }
      payout_recipient: {
        Args: { p_claim: string; p_code: string }
        Returns: undefined
      }
      payout_result: {
        Args: {
          p_note?: string
          p_ref: string
          p_status: string
          p_transfer_code?: string
        }
        Returns: Json
      }
      plan_update: {
        Args: {
          p_done_day?: number
          p_plan: string
          p_reminders?: boolean
          p_stop?: boolean
        }
        Returns: undefined
      }
      prize_claim: {
        Args: {
          p_account_name: string
          p_account_number: string
          p_adult: boolean
          p_bank: string
          p_guardian_name?: string
          p_guardian_phone?: string
          p_id: string
        }
        Returns: Json
      }
      prize_claim_v2: {
        Args: {
          p_account_name: string
          p_account_number: string
          p_adult: boolean
          p_bank: string
          p_bank_code: string
          p_guardian_name?: string
          p_guardian_phone?: string
          p_id: string
        }
        Returns: Json
      }
      public_classes: { Args: never; Returns: Json }
      push_cron_ok: { Args: { p_token: string }; Returns: boolean }
      push_done: {
        Args: { p_error: string; p_id: string; p_sent: number }
        Returns: undefined
      }
      push_kick: { Args: never; Returns: undefined }
      push_take_due: { Args: { p_limit?: number }; Returns: Json }
      qotd_answer: { Args: { p_choice: string }; Returns: Json }
      qotd_today: { Args: never; Returns: Json }
      quote_price: { Args: { p_code?: string; p_plan: string }; Returns: Json }
      redeem_code: { Args: { p_code: string }; Returns: Json }
      referral_apply: { Args: { p_code: string }; Returns: Json }
      referral_claim: {
        Args: {
          p_account_name: string
          p_account_number: string
          p_bank: string
          p_reward: string
        }
        Returns: Json
      }
      register_push_token: {
        Args: { p_platform?: string; p_token: string; p_version?: string }
        Returns: undefined
      }
      set_birth_year: { Args: { p_year: number }; Returns: Json }
      set_questions_status: {
        Args: {
          p_ids: string[]
          p_status: Database["public"]["Enums"]["content_status"]
        }
        Returns: number
      }
      streak_buy_freeze: { Args: never; Returns: Json }
      streak_repair: { Args: never; Returns: Json }
      streak_seen: { Args: { p_key: string }; Returns: undefined }
      study_catalog: {
        Args: { p_kind: string; p_subject?: number }
        Returns: {
          exam_id: number
          id: string
          is_free: boolean
          kind: string
          locked: boolean
          meta: Json
          question_id: string
          sort: number
          subject_id: number
          subtitle: string
          title: string
          topic: string
          topic_id: number
          year: number
        }[]
      }
      study_cover_key: { Args: { p_id: string }; Returns: string }
      study_file_key: {
        Args: { p_file: string; p_id: string }
        Returns: string
      }
      study_item: { Args: { p_id: string }; Returns: Json }
      submit_attempt: { Args: { p: Json }; Returns: Json }
      today_motivation: { Args: never; Returns: Json }
      tutor_chats: { Args: { p_scope?: string }; Returns: Json }
      tutor_custom_request: { Args: { p_request: string; p_note: string }; Returns: Json }
      tutor_file_ok: { Args: { p_request: string }; Returns: boolean }
      tutor_mark_read: { Args: { p_request: string }; Returns: number }
      tutor_message_send: { Args: { p_request: string; p_body: string; p_kind?: string; p_attachment?: string; p_meta?: Json; p_ref?: Json }; Returns: Json }
      tutor_messages_before: { Args: { p_request: string; p_before: number; p_limit?: number }; Returns: Json }
      tutor_overview: { Args: never; Returns: Json }
      tutor_profile_save: { Args: { p_name: string; p_subjects: string; p_bio: string }; Returns: Json }
      tutor_ref_search: { Args: { p_kind: string; p_q?: string; p_subject?: number }; Returns: Json }
      tutor_request_create: { Args: { p_subject: number; p_level: string; p_goals: string; p_times: string }; Returns: Json }
      tutor_student_profile: { Args: { p_request: string }; Returns: Json }
      undo_import: { Args: { p_batch: string }; Returns: number }
      winners_wall_list: { Args: never; Returns: Json }
      xp_buy_premium: { Args: { p_plan: string }; Returns: Json }
      xp_claim_daily: { Args: never; Returns: Json }
      xp_pack_start: {
        Args: { p_source?: string; p_uid: string; p_xp: number }
        Returns: Json
      }
      deleted_users_done: {
        Args: { p_ids: string[]; p_what: string }
        Returns: number
      }
      deleted_users_pending: {
        Args: { p_limit?: number; p_what: string }
        Returns: string[]
      }
      inactive_due: {
        Args: { p_limit?: number }
        Returns: Json
      }
      inactive_mark: {
        Args: { p_ids: string[] }
        Returns: number
      }
      admin_analytics: {
        Args: { p_days?: number }
        Returns: Json
      }
      email_outbox_due: { Args: { p_limit?: number }; Returns: Json }
      email_outbox_mark: { Args: { p_error?: string; p_id: number; p_ok: boolean }; Returns: undefined }
      admin_email_outbox: { Args: Record<PropertyKey, never>; Returns: Json }
      delete_code_start: { Args: { p_hash: string; p_note: string; p_reason: string; p_user: string }; Returns: string }
      delete_code_check: { Args: { p_hash: string; p_user: string }; Returns: Json }
      delete_reason_log: { Args: { p_note: string; p_reason: string; p_user: string; p_via: string }; Returns: undefined }
      minor_win_notices_due: {
        Args: { p_limit?: number }
        Returns: Json
      }
      minor_win_notice_mark: {
        Args: { p_error?: string; p_id: number; p_ok: boolean }
        Returns: undefined
      }
      admin_minor_win_notices: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      question_sources: {
        Args: { p_ids: string[] }
        Returns: Json
      }
      admin_past_questions: {
        Args: { p_on: boolean }
        Returns: Json
      }
      admin_question_sources: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      admin_paystack_fee_check: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      admin_paystack_keys: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      admin_set_paystack_key: {
        Args: { p_name: string; p_value: string }
        Returns: Json
      }
      admin_set_paystack_mode: {
        Args: { p_mode: string }
        Returns: Json
      }
    }
    Enums: {
      attempt_status: "submitted" | "abandoned"
      content_status: "draft" | "review" | "published"
      difficulty: "easy" | "medium" | "hard"
      entitlement_source:
        | "manual"
        | "paystack"
        | "play"
        | "code"
        | "referral"
        | "prize"
        | "xp"
      notif_topic:
        | "announcements"
        | "new_questions"
        | "streak"
        | "classes"
        | "challenges"
        | "account"
      payment_status:
        | "pending"
        | "success"
        | "failed"
        | "abandoned"
        | "needs_review"
        | "refunded"
      promo_kind: "pct" | "amt" | "days"
      staff_role: "super_admin" | "admin" | "editor" | "teacher" | "tutor"
      year_status: "draft" | "published"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      attempt_status: ["submitted", "abandoned"],
      content_status: ["draft", "review", "published"],
      difficulty: ["easy", "medium", "hard"],
      entitlement_source: [
        "manual",
        "paystack",
        "play",
        "code",
        "referral",
        "prize",
        "xp",
      ],
      notif_topic: [
        "announcements",
        "new_questions",
        "streak",
        "classes",
        "challenges",
        "account",
      ],
      payment_status: [
        "pending",
        "success",
        "failed",
        "abandoned",
        "needs_review",
        "refunded",
      ],
      promo_kind: ["pct", "amt", "days"],
      staff_role: ["super_admin", "admin", "editor", "teacher", "tutor"],
      year_status: ["draft", "published"],
    },
  },
} as const
