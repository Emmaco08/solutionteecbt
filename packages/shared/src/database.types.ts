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
      device_events: {
        Row: { at: string; detail: string | null; device_hash: string | null; id: number; kind: string; user_id: string | null }
        Insert: { at?: string; detail?: string | null; device_hash?: string | null; id?: never; kind: string; user_id?: string | null }
        Update: { at?: string; detail?: string | null; device_hash?: string | null; id?: never; kind?: string; user_id?: string | null }
        Relationships: []
      }
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
          title: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          subject_id?: number | null
          title?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          subject_id?: number | null
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
      ai_messages: {
        Row: {
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
          role: string
          user_id: string
        }
        Insert: {
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
          role: string
          user_id: string
        }
        Update: {
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
          id: string
          mode: string
          question_ids: string[]
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
          id: string
          mode: string
          question_ids: string[]
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
          id?: string
          mode?: string
          question_ids?: string[]
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
      challenge_answers: {
        Row: {
          answered_at: string
          choice: string | null
          correct: boolean
          entry_id: string
          question_id: string
          time_ms: number
        }
        Insert: {
          answered_at?: string
          choice?: string | null
          correct?: boolean
          entry_id: string
          question_id: string
          time_ms: number
        }
        Update: {
          answered_at?: string
          choice?: string | null
          correct?: boolean
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
          challenge_id: string
          current: number
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
          time_ms: number
          user_id: string
        }
        Insert: {
          challenge_id: string
          current?: number
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
          time_ms?: number
          user_id: string
        }
        Update: {
          challenge_id?: string
          current?: number
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
          time_ms?: number
          user_id?: string
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
      challenge_questions: {
        Row: {
          answer: string
          body: string
          challenge_id: string
          created_at: string
          difficulty: string
          explanation: string | null
          id: string
          options: Json
          position: number
          source_question_id: string | null
          subject_id: number | null
        }
        Insert: {
          answer: string
          body: string
          challenge_id: string
          created_at?: string
          difficulty?: string
          explanation?: string | null
          id?: string
          options: Json
          position?: number
          source_question_id?: string | null
          subject_id?: number | null
        }
        Update: {
          answer?: string
          body?: string
          challenge_id?: string
          created_at?: string
          difficulty?: string
          explanation?: string | null
          id?: string
          options?: Json
          position?: number
          source_question_id?: string | null
          subject_id?: number | null
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
          allowed_exits: number
          announced_at: string | null
          closed_at: string | null
          created_at: string
          created_by: string | null
          end_notified_at: string | null
          ends_at: string
          exam_code: string | null
          icon: string
          id: string
          kind: string
          mode: string
          per_level: Json
          premium_days: number
          premium_top: number
          prizes: number[]
          published: boolean
          reward_text: string | null
          allow_calculator: boolean
          bg_dark: string | null
          bg_light: string | null
          max_players: number | null
          min_win_pct: number | null
          allow_review: boolean
          xp_fee: number
          same_questions: boolean
          seconds_per_question: number
          soon_notified_at: string | null
          starts_at: string
          subject_id: number | null
          subtitle: string | null
          title: string
          updated_at: string
        }
        Insert: {
          allowed_exits?: number
          announced_at?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          end_notified_at?: string | null
          ends_at: string
          exam_code?: string | null
          icon?: string
          id?: string
          kind?: string
          mode?: string
          per_level?: Json
          premium_days?: number
          premium_top?: number
          prizes?: number[]
          published?: boolean
          reward_text?: string | null
          allow_calculator?: boolean
          bg_dark?: string | null
          bg_light?: string | null
          max_players?: number | null
          min_win_pct?: number | null
          allow_review?: boolean
          xp_fee?: number
          same_questions?: boolean
          seconds_per_question?: number
          soon_notified_at?: string | null
          starts_at: string
          subject_id?: number | null
          subtitle?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          allowed_exits?: number
          announced_at?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          end_notified_at?: string | null
          ends_at?: string
          exam_code?: string | null
          icon?: string
          id?: string
          kind?: string
          mode?: string
          per_level?: Json
          premium_days?: number
          premium_top?: number
          prizes?: number[]
          published?: boolean
          reward_text?: string | null
          allow_calculator?: boolean
          bg_dark?: string | null
          bg_light?: string | null
          max_players?: number | null
          min_win_pct?: number | null
          allow_review?: boolean
          xp_fee?: number
          same_questions?: boolean
          seconds_per_question?: number
          soon_notified_at?: string | null
          starts_at?: string
          subject_id?: number | null
          subtitle?: string | null
          title?: string
          updated_at?: string
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
      exam_bodies: {
        Row: {
          code: string
          id: number
          is_active: boolean
          logo_path: string | null
          name: string
          sort: number
        }
        Insert: {
          code: string
          id?: never
          is_active?: boolean
          logo_path?: string | null
          name: string
          sort?: number
        }
        Update: {
          code?: string
          id?: never
          is_active?: boolean
          logo_path?: string | null
          name?: string
          sort?: number
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
        Row: { active: boolean; author: string | null; body: string; created_at: string; id: number; kind: string; sort: number }
        Insert: { active?: boolean; author?: string | null; body: string; created_at?: string; id?: never; kind?: string; sort?: number }
        Update: { active?: boolean; author?: string | null; body?: string; created_at?: string; id?: never; kind?: string; sort?: number }
        Relationships: []
      }
      news_posts: {
        Row: {
          body: string | null
          category: string
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
          amount_kobo: number
          channel: string | null
          code_id: string | null
          created_at: string
          currency: string
          discount_kobo: number
          entitlement_id: string | null
          id: string
          list_kobo: number
          plan_id: number
          provider: string
          provider_data: Json
          purchase_token: string | null
          reference: string
          refunded_at: string | null
          source: string
          status: Database["public"]["Enums"]["payment_status"]
          updated_at: string
          user_id: string | null
          verified_at: string | null
        }
        Insert: {
          amount_kobo: number
          channel?: string | null
          code_id?: string | null
          created_at?: string
          currency?: string
          discount_kobo?: number
          entitlement_id?: string | null
          id?: string
          list_kobo: number
          plan_id: number
          provider: string
          provider_data?: Json
          purchase_token?: string | null
          reference: string
          refunded_at?: string | null
          source?: string
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id?: string | null
          verified_at?: string | null
        }
        Update: {
          amount_kobo?: number
          channel?: string | null
          code_id?: string | null
          created_at?: string
          currency?: string
          discount_kobo?: number
          entitlement_id?: string | null
          id?: string
          list_kobo?: number
          plan_id?: number
          provider?: string
          provider_data?: Json
          purchase_token?: string | null
          reference?: string
          refunded_at?: string | null
          source?: string
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
          user_id?: string | null
          verified_at?: string | null
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
          payout_at: string | null
          payout_by: string | null
          payout_error: string | null
          recipient_code: string | null
          transfer_code: string | null
          payout_ref: string | null
          payout_status: string
          verified_name: string | null
          bank_code: string | null
          bank_name: string
          created_at: string
          entry_id: string
          guardian_name: string | null
          guardian_phone: string | null
          id: string
          paid_at: string | null
          paid_by: string | null
          status: string
          user_id: string
        }
        Insert: {
          account_name: string
          account_number: string
          admin_note?: string | null
          adult: boolean
          amount: number
          bank_name: string
          created_at?: string
          entry_id: string
          guardian_name?: string | null
          guardian_phone?: string | null
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          status?: string
          user_id: string
        }
        Update: {
          account_name?: string
          account_number?: string
          admin_note?: string | null
          adult?: boolean
          amount?: number
          payout_at?: string | null
          payout_by?: string | null
          payout_error?: string | null
          recipient_code?: string | null
          transfer_code?: string | null
          payout_ref?: string | null
          payout_status?: string
          verified_name?: string | null
          bank_code?: string | null
          bank_name?: string
          created_at?: string
          entry_id?: string
          guardian_name?: string | null
          guardian_phone?: string | null
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          status?: string
          user_id?: string
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
      profiles: {
        Row: {
          avatar_path: string | null
          ban_reason: string | null
          banned_at: string | null
          created_at: string
          full_name: string | null
          hide_on_leaderboard: boolean
          id: string
          jamb_subjects: string[]
          phone: string | null
          school: string | null
          show_photo_on_leaderboard: boolean
          state: string | null
          target_exams: string[]
          target_score: number | null
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          ban_reason?: string | null
          banned_at?: string | null
          created_at?: string
          full_name?: string | null
          hide_on_leaderboard?: boolean
          id: string
          jamb_subjects?: string[]
          phone?: string | null
          school?: string | null
          show_photo_on_leaderboard?: boolean
          state?: string | null
          target_exams?: string[]
          target_score?: number | null
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          ban_reason?: string | null
          banned_at?: string | null
          created_at?: string
          full_name?: string | null
          hide_on_leaderboard?: boolean
          id?: string
          jamb_subjects?: string[]
          phone?: string | null
          school?: string | null
          show_photo_on_leaderboard?: boolean
          state?: string | null
          target_exams?: string[]
          target_score?: number | null
          updated_at?: string
        }
        Relationships: []
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
      study_items: {
        Row: {
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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_ai_health: { Args: never; Returns: Json }
      admin_archive_codes: {
        Args: { p_batch: string; p_id: string }
        Returns: number
      }
      admin_batch_codes: {
        Args: { p_batch: string }
        Returns: {
          code: string
          used: number
        }[]
      }
      admin_ban_device: { Args: { p_hash: string; p_reason: string }; Returns: Json }
      admin_device_appeal: {
        Args: { p_accept: boolean; p_id: string; p_note?: string }
        Returns: Json
      }
      admin_device_allow: {
        Args: { p_allowed: boolean; p_hash: string; p_user: string }
        Returns: undefined
      }
      admin_fraud: { Args: never; Returns: Json }
      admin_referral_paid: {
        Args: { p_note?: string; p_receipt?: string; p_reward: string }
        Returns: undefined
      }
      admin_referral_settings: { Args: { p: Json }; Returns: undefined }
      admin_referrals: { Args: never; Returns: Json }
      admin_challenge_appeal: {
        Args: { p_accept: boolean; p_appeal: string; p_note?: string }
        Returns: Json
      }
      admin_challenge_appeals: { Args: never; Returns: Json }
      admin_ban: {
        Args: { p_banned: boolean; p_linked?: boolean; p_reason?: string; p_user: string }
        Returns: Json
      }
      admin_ban_appeal: {
        Args: { p_accept: boolean; p_appeal: string; p_note?: string }
        Returns: undefined
      }
      admin_unban_device: { Args: { p_hash: string }; Returns: Json }
      admin_xp_adjust: { Args: { p_amount: number; p_reason: string; p_user: string }; Returns: Json }
      admin_xp_overview: { Args: never; Returns: Json }
      admin_xp_settings: { Args: { p: Json }; Returns: undefined }
      admin_xp_user: { Args: { p_query: string }; Returns: Json }
      admin_challenge_add_random: {
        Args: { p_count: number; p_id: string; p_subjects: number[] }
        Returns: Json
      }
      admin_challenge_close: { Args: { p_id: string }; Returns: Json }
      admin_challenge_copy: {
        Args: { p_id: string; p_starts: string }
        Returns: string
      }
      admin_challenge_entries: { Args: { p_id: string }; Returns: Json }
      admin_challenge_live: { Args: { p_id: string }; Returns: Json }
      admin_challenge_set_review: {
        Args: { p_id: string; p_on: boolean }
        Returns: undefined
      }
      admin_challenge_set_level: {
        Args: { p_level: string; p_question: string }
        Returns: undefined
      }
      admin_challenge_review: {
        Args: { p_decision: string; p_entry: string }
        Returns: Json
      }
      admin_codes: { Args: never; Returns: Json }
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
      admin_set_ai_key: {
        Args: { p_key: string; p_provider: string }
        Returns: string
      }
      admin_set_ban: {
        Args: { p_banned: boolean; p_reason?: string; p_user: string }
        Returns: undefined
      }
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
      admin_year_counts: {
        Args: { p_exam: number }
        Returns: {
          published: number
          subject_id: number
          total: number
          year: number
        }[]
      }
      ai_chunk_sources: {
        Args: { p_source: string }
        Returns: {
          indexed_at: string
          source_id: string
        }[]
      }
      ai_config: { Args: never; Returns: Json }
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
      ai_provider_key: { Args: { p_provider: string }; Returns: string }
      ai_quota: { Args: never; Returns: Json }
      ai_refund: { Args: { p_uid: string }; Returns: undefined }
      ai_take: { Args: { p_uid: string }; Returns: number }
      am_money_admin: { Args: never; Returns: boolean }
      am_notifier: { Args: never; Returns: boolean }
      auth_user_status: { Args: { p_email: string }; Returns: string }
      prize_claim_v2: { Args: { p_id: string; p_adult: boolean; p_bank: string; p_bank_code: string; p_account_number: string; p_account_name: string; p_guardian_name?: string; p_guardian_phone?: string }; Returns: Json }
      can_view_challenge_image: { Args: { p_key: string }; Returns: boolean }
      my_practice_today: { Args: never; Returns: Json }
      can_upload_images: { Args: never; Returns: boolean }
      can_view_avatar: { Args: { p_key: string }; Returns: boolean }
      can_view_note_image: { Args: { p_key: string }; Returns: boolean }
      can_view_question_image: { Args: { p_key: string }; Returns: boolean }
      can_view_study_file: { Args: { p_key: string }; Returns: boolean }
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
      challenge_result: { Args: { p_id: string }; Returns: Json }
      ban_appeal: { Args: { p_reason: string }; Returns: Json }
      device_appeal: {
        Args: { p_email: string; p_ids: string[]; p_reason: string }
        Returns: Json
      }
      device_check_in: { Args: { p_flags?: string[]; p_ids: string[] }; Returns: Json }
      device_register: { Args: { p_hash: string }; Returns: Json }
      device_status: { Args: { p_ids: string[] }; Returns: Json }
      my_referrals: { Args: never; Returns: Json }
      my_status: { Args: never; Returns: Json }
      my_xp: { Args: never; Returns: Json }
      xp_buy_premium: { Args: { p_plan: string }; Returns: Json }
      xp_claim_daily: { Args: never; Returns: Json }
      referral_apply: { Args: { p_code: string }; Returns: Json }
      referral_claim: {
        Args: { p_account_name: string; p_account_number: string; p_bank: string; p_reward: string }
        Returns: Json
      }
      challenge_report: {
        Args: { p_entry: string; p_what: string }
        Returns: undefined
      }
      challenge_review: { Args: { p_id: string }; Returns: Json }
      challenge_start: {
        Args: { p_device?: string; p_device_flags?: string[]; p_id: string }
        Returns: Json
      }
      challenges_list: { Args: never; Returns: Json }
      email_send_allowed: {
        Args: { p_email_hash: string; p_ip_hash: string | null; p_kind: string }
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
      import_questions: {
        Args: { p_dry_run?: boolean; p_file_name: string; p_rows: Json }
        Returns: Json
      }
      leaderboard: {
        Args: { p_scope?: string; p_season?: number }
        Returns: Json
      }
      leaderboard_for: {
        Args: {
          p_exam?: string
          p_scope?: string
          p_season?: number
          p_subject?: number
        }
        Returns: Json
      }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      my_badges: { Args: never; Returns: Json }
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
      today_motivation: { Args: never; Returns: Json }
      my_winnings: { Args: never; Returns: Json }
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
      push_cron_ok: { Args: { p_token: string }; Returns: boolean }
      push_done: {
        Args: { p_error: string; p_id: string; p_sent: number }
        Returns: undefined
      }
      push_take_due: { Args: { p_limit?: number }; Returns: Json }
      qotd_answer: { Args: { p_choice: string }; Returns: Json }
      qotd_today: { Args: never; Returns: Json }
      quote_price: { Args: { p_code?: string; p_plan: string }; Returns: Json }
      redeem_code: { Args: { p_code: string }; Returns: Json }
      register_push_token: {
        Args: { p_platform?: string; p_token: string; p_version?: string }
        Returns: undefined
      }
      set_questions_status: {
        Args: {
          p_ids: string[]
          p_status: Database["public"]["Enums"]["content_status"]
        }
        Returns: number
      }
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
      undo_import: { Args: { p_batch: string }; Returns: number }
      winners_wall_list: { Args: never; Returns: Json }
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
      staff_role: "super_admin" | "admin" | "editor" | "teacher"
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
      staff_role: ["super_admin", "admin", "editor", "teacher"],
      year_status: ["draft", "published"],
    },
  },
} as const
