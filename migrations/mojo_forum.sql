-- 1 up
create table if not exists posts (
  id    integer primary key autoincrement,
  title text,
  body  text
);
 
-- 1 down
drop table if exists posts;

-- 2 up
create table if not exists chats (
  id    integer primary key autoincrement,
  body  text
);
 
-- 2 down
drop table if exists chats;

-- 3 up
create table if not exists users (
  id    integer primary key autoincrement,
  email string unique,
	hashed_password string,
	created_at text,
	updated_at text,
	username text unique,
	contactme integer default 1,
	phone text,
	password_reset_token text,
	password_reset_expiry integer
);
 
-- 3 down
drop table if exists users;
