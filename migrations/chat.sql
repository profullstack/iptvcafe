-- 2 up
create table if not exists chats (
  id    integer primary key autoincrement,
  body  text
);
 
-- 2 down
drop table if exists chats;
