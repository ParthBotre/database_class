-- VideoPlatform — database creation, DDL, views, and graded DML example queries.
-- Run order: (1) Execute this entire script in MySQL Workbench. (2) Run seed_sample_data.sql
-- to load sample rows. (3) Re-run the Basic/Complex DML sections at the bottom if you want
-- those SELECTs to return populated result sets (first run executes them on empty tables).
-- `User` is quoted because USER is a reserved word in MySQL.

DROP DATABASE IF EXISTS VideoPlatform;
CREATE DATABASE VideoPlatform;
USE VideoPlatform;

-- =========================
-- DDL: `User`
-- =========================
-- Stores every account. Specialized roles (creator, viewer, moderator) hang child rows
-- off this table via matching user_id PK/FK (overlapping subtypes pattern).
CREATE TABLE `User` (
    user_id INT PRIMARY KEY,
    username VARCHAR(50),
    email VARCHAR(100)
) ENGINE=InnoDB;

-- =========================
-- DDL: Creator
-- =========================
-- Users who publish videos and streams; subscriber_count is denormalized channel stat.
CREATE TABLE Creator (
    user_id INT PRIMARY KEY,
    subscriber_count INT,
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: Viewer
-- =========================
-- Users who consume content; subscription edges reference Viewer.user_id.
CREATE TABLE Viewer (
    user_id INT PRIMARY KEY,
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: Moderator
-- =========================
-- Staff accounts; permissions live in ModeratorPermissionLevel.
CREATE TABLE Moderator (
    user_id INT PRIMARY KEY,
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: ModeratorPermissionLevel
-- =========================
-- DML later: moderators may have different scopes (e.g. full vs region-limited).
CREATE TABLE ModeratorPermissionLevel (
    permission_id INT PRIMARY KEY,
    user_id INT,
    permission_level VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES Moderator(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: Video
-- =========================
-- On-demand uploads; must belong to a Creator (FK to Creator.user_id).
CREATE TABLE Video (
    video_id INT PRIMARY KEY,
    user_id INT,
    views INT,
    like_count INT,
    dislike_count INT,
    FOREIGN KEY (user_id) REFERENCES Creator(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: VideoSubtitle
-- =========================
-- Community captions; FK to Video and to `User` (any account may contribute).
CREATE TABLE VideoSubtitle (
    subtitle_id INT PRIMARY KEY,
    video_id INT,
    user_id INT,
    subtitle_text TEXT,
    FOREIGN KEY (video_id) REFERENCES Video(video_id),
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: Comment
-- =========================
-- Threaded feedback on a video. Column `text` is quoted (TEXT is a reserved type name).
CREATE TABLE Comment (
    comment_id INT PRIMARY KEY,
    video_id INT,
    user_id INT,
    `text` TEXT,
    `timestamp` DATETIME,
    FOREIGN KEY (video_id) REFERENCES Video(video_id),
    FOREIGN KEY (user_id) REFERENCES `User`(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: SubscribesTo
-- =========================
-- Many-to-many: which viewers follow which creators (composite PK).
CREATE TABLE SubscribesTo (
    user_id INT,
    creator_id INT,
    PRIMARY KEY (user_id, creator_id),
    FOREIGN KEY (user_id) REFERENCES Viewer(user_id),
    FOREIGN KEY (creator_id) REFERENCES Creator(user_id)
) ENGINE=InnoDB;

-- =========================
-- DDL: Stream
-- =========================
-- Live broadcasts owned by a creator (separate lifecycle from Video rows).
CREATE TABLE Stream (
    stream_id INT PRIMARY KEY,
    user_id INT,
    title VARCHAR(200),
    started_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES Creator(user_id)
) ENGINE=InnoDB;

-- =========================
-- Views: different users, different SQL perspectives
-- =========================
-- Creator dashboard: each creator sees only their own uploads and live streams.
CREATE VIEW v_creator_dashboard AS
SELECT
    u.user_id,
    u.username,
    'video' AS content_type,
    v.video_id AS content_id,
    v.views,
    v.like_count,
    v.dislike_count
FROM Creator c
JOIN `User` u ON u.user_id = c.user_id
JOIN Video v ON v.user_id = c.user_id
UNION ALL
SELECT
    u.user_id,
    u.username,
    'stream',
    s.stream_id,
    0,
    0,
    0
FROM Creator c
JOIN `User` u ON u.user_id = c.user_id
JOIN Stream s ON s.user_id = c.user_id;

-- Viewer digest: one row per subscription edge (what this viewer follows).
CREATE VIEW v_viewer_digest AS
SELECT
    vu.user_id AS viewer_id,
    vu.username AS viewer,
    cu.username AS subscribed_creator
FROM Viewer vi
JOIN `User` vu ON vu.user_id = vi.user_id
JOIN SubscribesTo st ON st.user_id = vi.user_id
JOIN `User` cu ON cu.user_id = st.creator_id;

-- Moderator oversight: platform-wide engagement plus “review queue” style signal
-- (videos whose dislike share of reactions exceeds 5% — nested + aggregated logic).
CREATE VIEW v_moderator_oversight AS
SELECT
    v.video_id,
    u.username AS creator,
    v.views,
    v.like_count,
    v.dislike_count,
    ROUND(100.0 * v.dislike_count / NULLIF(v.like_count + v.dislike_count, 0), 2) AS dislike_pct,
    (SELECT COUNT(*) FROM Comment cm WHERE cm.video_id = v.video_id) AS comment_count
FROM Video v
JOIN Creator cr ON cr.user_id = v.user_id
JOIN `User` u ON u.user_id = cr.user_id;

-- =========================
-- Basic DML: simple retrieval
-- =========================
-- Sample rows live in seed_sample_data.sql. Re-run this block after seeding for non-empty results.

-- List all registered accounts (projection + ordering).
SELECT user_id, username, email
FROM `User`
ORDER BY user_id;

-- Filter: creators above a subscriber threshold (selection on one table + WHERE).
SELECT user_id, subscriber_count
FROM Creator
WHERE subscriber_count >= 500
ORDER BY subscriber_count DESC;

-- Join two tables: who commented, and on which video id (relational retrieval).
SELECT u.username, c.video_id, c.`text`
FROM Comment c
JOIN `User` u ON u.user_id = c.user_id
ORDER BY c.`timestamp` DESC;

-- =========================
-- Complex DML: joins, aggregates, nested queries
-- =========================

-- Multi-table join: each subscription row with viewer and creator names.
SELECT
    vu.username AS viewer,
    cu.username AS creator
FROM SubscribesTo st
JOIN `User` vu ON vu.user_id = st.user_id
JOIN `User` cu ON cu.user_id = st.creator_id
ORDER BY vu.username, cu.username;

-- Aggregation: total views and likes per creator (GROUP BY + SUM).
SELECT
    u.username,
    SUM(v.views) AS total_views,
    SUM(v.like_count) AS total_likes
FROM Video v
JOIN Creator c ON c.user_id = v.user_id
JOIN `User` u ON u.user_id = c.user_id
GROUP BY u.user_id, u.username
ORDER BY total_views DESC;

-- HAVING: creators whose average video views exceed 1000 (two-level filter: aggregate then HAVING).
SELECT
    u.username,
    AVG(v.views) AS avg_video_views
FROM Video v
JOIN Creator c ON c.user_id = v.user_id
JOIN `User` u ON u.user_id = c.user_id
GROUP BY u.user_id, u.username
HAVING AVG(v.views) > 1000;

-- Non-correlated subquery: videos with above-average views for the platform.
SELECT v.video_id, u.username, v.views
FROM Video v
JOIN Creator c ON c.user_id = v.user_id
JOIN `User` u ON u.user_id = c.user_id
WHERE v.views > (SELECT AVG(v2.views) FROM Video v2)
ORDER BY v.views DESC;

-- Nested subquery in FROM: rank creators by subscriber_count (MySQL 5.7–safe rank).
SELECT ranked.username, ranked.subscriber_count, ranked.rnk
FROM (
    SELECT
        u.username,
        c.subscriber_count,
        (SELECT 1 + COUNT(*)
         FROM Creator c2
         WHERE c2.subscriber_count > c.subscriber_count) AS rnk
    FROM Creator c
    JOIN `User` u ON u.user_id = c.user_id
) AS ranked
ORDER BY ranked.rnk;

-- Correlated subquery: count subtitles contributed per user for users who also commented.
SELECT DISTINCT u.user_id, u.username,
       (SELECT COUNT(*) FROM VideoSubtitle vs WHERE vs.user_id = u.user_id) AS subtitle_rows,
       (SELECT COUNT(*) FROM Comment cm WHERE cm.user_id = u.user_id) AS comment_rows
FROM `User` u
WHERE EXISTS (SELECT 1 FROM Comment cm2 WHERE cm2.user_id = u.user_id)
ORDER BY u.user_id;

-- Correlated scalar subquery: viewers who follow at least two distinct creators.
SELECT vu.username
FROM Viewer vi
JOIN `User` vu ON vu.user_id = vi.user_id
WHERE (SELECT COUNT(*) FROM SubscribesTo st WHERE st.user_id = vi.user_id) >= 2;
