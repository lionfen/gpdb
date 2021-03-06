-- negative cases
SELECT test_receive();
SELECT test_send();
SELECT test_disconnect();

-- Wait until number of replication sessions drop to 0 or timeout
-- occurs. Returns false if timeout occured.
create function check_and_wait_for_replication(
   timeout int)
returns boolean as
$$
declare
   d bigint;
   i  int;
begin
   i := 0;
   loop
      SELECT count(*) into d FROM pg_stat_replication;
      if (d = 0) then
         return true;
      end if;
      if i >= $1 then
         return false;
      end if;
      perform pg_sleep(.5);
      i := i + 1;
   end loop;
end;
$$ language plpgsql;

-- Test connection
SELECT test_connect('', pg_current_xlog_location());
-- Should report 1 replication
SELECT count(*) FROM pg_stat_replication;
SELECT test_disconnect();
SELECT check_and_wait_for_replication(10);

-- Test connection passing hostname
SELECT test_connect('host=localhost', pg_current_xlog_location());
SELECT count(*) FROM pg_stat_replication;
SELECT test_disconnect();
SELECT check_and_wait_for_replication(10);

-- create table and store current_xlog_location.
create TEMP table tmp(startpoint text);
CREATE FUNCTION select_tmp() RETURNS text AS $$
select startpoint from tmp;
$$ LANGUAGE SQL;
insert into tmp select pg_current_xlog_location();

-- lets generate some xlogs
create table testwalreceiver(a int);
insert into testwalreceiver select * from generate_series(0, 9);

-- Connect and receive the xlogs, validate everything was received from start to
-- end
SELECT test_connect('', select_tmp());
SELECT test_receive_and_verify(select_tmp(), pg_current_xlog_location());
SELECT test_send();
SELECT test_receive();
SELECT test_disconnect();
