-- admin_analytics builds temporary working tables, so it must be VOLATILE (D-124).
alter function public.admin_analytics(int) volatile;
