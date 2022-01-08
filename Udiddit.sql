CREATE TABLE "users" (
  "id" SERIAL PRIMARY KEY,
  "username" VARCHAR(25) NOT NULL,
  "last_login" TIMESTAMP,
  CONSTRAINT "username_emptiness" CHECK (LENGTH(TRIM("username")) >0)
);
CREATE UNIQUE INDEX "unique_username_lower_case" ON "users" (LOWER("username"));


CREATE TABLE "topics" (
  "id" SERIAL PRIMARY KEY,
  "name" VARCHAR(30) NOT NULL,
  "description" VARCHAR(500),
  CONSTRAINT "topic_name_emptiness" CHECK (LENGTH(TRIM("name")) >0)
);
CREATE UNIQUE INDEX "unique_topic" ON "topics" (TRIM("name"));
CREATE INDEX "partial_match_topic_name" ON "topics" (LOWER("name") VARCHAR_PATTERN_OPS);

CREATE TABLE "posts" (
  "id" SERIAL PRIMARY KEY,
  "title" VARCHAR(200) NOT NULL,
  "url" VARCHAR(2000),
  "text_content" TEXT,
  "topic_id" INTEGER NOT NULL REFERENCES "topics" ("id") ON DELETE CASCADE,
  "user_id" INTEGER REFERENCES "users" ("id") ON DELETE SET NULL,
  "post_timestamp" TIMESTAMP,
  CONSTRAINT "title_emptiness" CHECK (LENGTH(TRIM("title"))>0),
  CONSTRAINT "url_or_text" 
  CHECK(("url" IS NULL AND "text_content" IS NOT NULL) 
  OR ("url" IS NOT NULL AND "text_content" IS NULL)));
CREATE INDEX "topic_index" ON "posts" ("topic_id");
CREATE INDEX "users_index" ON "posts" ("user_id");

  
CREATE TABLE "votes" (
  "user_id" INTEGER REFERENCES "users" ("id") ON DELETE SET NULL,
  "post_id" INTEGER REFERENCES "posts" ("id") ON DELETE CASCADE,
  "vote" SMALLINT CHECK(("vote" = 1) OR ("vote" = -1)),
  PRIMARY KEY ("post_id", "user_id"));
  
CREATE TABLE "comments" (
  "id" SERIAL PRIMARY KEY,
  "parent_id" INTEGER REFERENCES "comments" ("id") ON DELETE CASCADE,
  "text_content" TEXT NOT NULL,
  "post_id" INTEGER NOT NULL REFERENCES "posts" ("id") ON DELETE CASCADE,
  "user_id" INTEGER REFERENCES "users" ("id") ON DELETE SET NULL,
  "comment_timestamp" TIMESTAMP,
  CONSTRAINT "comment_text_emptiness" CHECK (LENGTH(TRIM("text_content"))>0)
);

-- Migrate Data
INSERT INTO "users" ("username")
  SELECT DISTINCT username 
  FROM bad_comments 
  UNION 
  SELECT DISTINCT username
  FROM bad_posts
  UNION
  SELECT DISTINCT regexp_split_to_table(upvotes, ',') as username 
  FROM bad_posts
  UNION 
  SELECT DISTINCT regexp_split_to_table(downvotes, ',') as username 
  FROM bad_posts;

INSERT INTO "topics" ("name")
  SELECT DISTINCT topic from bad_posts;

INSERT INTO "posts" ("title", "url", "topic_id", "user_id")
  SELECT b.title, b.url, t.id as topic_id, u.id as user_id
  FROM bad_posts as b
  JOIN topics as t
  ON b.topic = t.name
  JOIN users as u
  ON b.username = u.username
  WHERE b.url IS NOT NULL;

INSERT INTO "posts" ("title", "text_content", "topic_id", "user_id")
  SELECT b.title, b.text_content, t.id as topic_id, u.id as user_id
  FROM bad_posts as b
  JOIN topics as t
  ON b.topic = t.name
  JOIN users as u
  ON b.username = u.username
  WHERE b.url IS NULL;
 
INSERT INTO "votes" ("post_id", "user_id", "vote")
  WITH sub AS (
    SELECT p.id AS post_id, regexp_split_to_table(upvotes, ',') AS upvote
    FROM bad_posts AS b
    JOIN posts AS p
    ON b.title = p.title)
  SELECT sub.post_id, u.id AS user_id, 1 AS vote
  FROM sub
  JOIN users AS u
  ON sub.upvote = u.username;

INSERT INTO "votes" ("post_id", "user_id", "vote")
  WITH sub AS (
    SELECT p.id AS post_id, regexp_split_to_table(downvotes, ',') AS downvote
    FROM bad_posts AS b
    JOIN posts AS p
    ON b.title = p.title)
  SELECT sub.post_id, u.id AS user_id, -1 AS vote
  FROM sub
  JOIN users AS u
  ON sub.downvote = u.username;

INSERT INTO "comments" ("user_id", "post_id", "text_content")
  SELECT u.id as user_id, p.id as post_id, b.text_content as text_content
  FROM bad_comments as b
  JOIN users as u
  ON b.username = u.username 
  JOIN bad_posts as bp
  ON b.post_id = bp.id
  JOIN posts as p
  ON bp.title = p.title;

DROP TABLE bad_comments;
DROP TABLE bad_posts;



