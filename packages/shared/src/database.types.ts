// Generated from the Supabase dev project (solutiontee-dev) on 2026-10-26. Do not edit by hand.
// Regenerate after schema changes (Supabase MCP generate_typescript_types or `supabase gen types`).
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
          publish_at?: string
          status?: Database["public"]["Enums"]["content_status"]
          summary?: string | null
          title?: string
          updated_at?: string
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
      profiles: {
        Row: {
          avatar_path: string | null
          ban_reason: string | null
          banned_at: string | null
          created_at: string
          full_name: string | null
          id: string
          jamb_subjects: string[]
          phone: string | null
          school: string | null
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
          id: string
          jamb_subjects?: string[]
          phone?: string | null
          school?: string | null
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
          id?: string
          jamb_subjects?: string[]
          phone?: string | null
          school?: string | null
          state?: string | null
          target_exams?: string[]
          target_score?: number | null
          updated_at?: string
        }
        Relationships: []
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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_dashboard: { Args: never; Returns: Json }
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
      admin_year_counts: {
        Args: { p_exam: number }
        Returns: { subject_id: number; year: number; total: number; published: number }[]
      }
      admin_list_staff: {
        Args: never
        Returns: {
          user_id: string
          email: string
          full_name: string | null
          role: Database["public"]["Enums"]["staff_role"]
          created_at: string
          last_sign_in_at: string | null
          has_2fa: boolean
        }[]
      }
      admin_user_detail: { Args: { p_user: string }; Returns: Json }
      email_send_allowed: { Args: { p_kind: string; p_email_hash: string; p_ip_hash: string | null }; Returns: string }
      email_sent_last_24h: { Args: never; Returns: number }
      auth_user_status: { Args: { p_email: string }; Returns: string }
      admin_set_ban: {
        Args: { p_banned: boolean; p_reason?: string; p_user: string }
        Returns: undefined
      }
      can_upload_images: { Args: never; Returns: boolean }
      can_view_question_image: { Args: { p_key: string }; Returns: boolean }
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
      set_questions_status: {
        Args: {
          p_ids: string[]
          p_status: Database["public"]["Enums"]["content_status"]
        }
        Returns: number
      }
      undo_import: { Args: { p_batch: string }; Returns: number }
    }
    Enums: {
      content_status: "draft" | "review" | "published"
      difficulty: "easy" | "medium" | "hard"
      entitlement_source:
        | "manual"
        | "paystack"
        | "play"
        | "code"
        | "referral"
        | "prize"
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
  T extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"]),
> = (DefaultSchema["Tables"] & DefaultSchema["Views"])[T] extends { Row: infer R } ? R : never

export type TablesInsert<T extends keyof DefaultSchema["Tables"]> =
  DefaultSchema["Tables"][T] extends { Insert: infer I } ? I : never

export type TablesUpdate<T extends keyof DefaultSchema["Tables"]> =
  DefaultSchema["Tables"][T] extends { Update: infer U } ? U : never

export type Enums<T extends keyof DefaultSchema["Enums"]> = DefaultSchema["Enums"][T]

export const Constants = {
  public: {
    Enums: {
      content_status: ["draft", "review", "published"],
      difficulty: ["easy", "medium", "hard"],
      entitlement_source: ["manual", "paystack", "play", "code", "referral", "prize"],
      staff_role: ["super_admin", "admin", "editor", "teacher"],
      year_status: ["draft", "published"],
    },
  },
} as const
