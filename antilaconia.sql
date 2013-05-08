CREATE TABLE users (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       name VARCHAR(20) UNIQUE,
       passsalt VARCHAR(200),
       passhash VARCHAR(200)       
);
CREATE TABLE posts (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       user_id INTEGER NOT NULL REFERENCES users (id),
       text VARCHAR(140)
);
