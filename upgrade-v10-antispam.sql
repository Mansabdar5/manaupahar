-- ManaUpahar Anti-Spam Upgrade (v10)
-- Run once in Supabase SQL Editor


-- ===== Anti-Spam Upgrades (v10) =====
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS visitor_id text;

CREATE OR REPLACE FUNCTION check_visitor_order_limit(p_visitor_id text, p_max_orders int DEFAULT 5, p_window_hours int DEFAULT 24)
RETURNS boolean AS $$
DECLARE
  order_count int;
BEGIN
  IF p_visitor_id IS NULL OR p_visitor_id = '' THEN
    RETURN true;
  END IF;

  SELECT count(*) INTO order_count
  FROM public.orders
  WHERE visitor_id = p_visitor_id
    AND created_at > (now() - (p_window_hours || ' hours')::interval);

  IF order_count >= p_max_orders THEN
    RAISE EXCEPTION 'Order limit reached for this visitor (% orders in % hours).', p_max_orders, p_window_hours;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cleanup_spam_orders(days_old int DEFAULT 30)
RETURNS int AS $$
DECLARE
  deleted_count int;
BEGIN
  DELETE FROM public.orders
  WHERE status IN ('cancelled', 'rejected', 'spam')
     OR (created_at < now() - (days_old || ' days')::interval AND status = 'new');
     
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_visitor_order_limit(text, int, int) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_spam_orders(int) TO authenticated;
