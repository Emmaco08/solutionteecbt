-- The "It is yours" notice after paying for one item needs a link (notifications.link is required): open Study.
do $$
declare d text := pg_get_functiondef('private.finish_payment(uuid,public.entitlement_source)'::regprocedure);
begin
  d := replace(d, '''Thanks! What you paid for is open for good.'', ''user'', p.user_id, ''scheduled'', now(), ''premium'', null)',
                  '''Thanks! What you paid for is open for good.'', ''user'', p.user_id, ''scheduled'', now(), ''premium'',
            jsonb_build_object(''type'', ''screen'', ''target'', ''/study''))');
  execute d;
end $$;
