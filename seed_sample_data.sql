-- Sample instances for VideoPlatform (DML INSERTs only).
-- Run project.sql first to create the VideoPlatform database, tables, and views; then run this file.

USE VideoPlatform;

INSERT INTO `User` (user_id, username, email) VALUES
  (1, 'alice_creator', 'alice@example.com'),
  (2, 'bob_creator', 'bob@example.com'),
  (3, 'carol_viewer', 'carol@example.com'),
  (4, 'dave_viewer', 'dave@example.com'),
  (5, 'erin_mod', 'erin@example.com');

INSERT INTO Creator (user_id, subscriber_count) VALUES
  (1, 1200),
  (2, 450);

INSERT INTO Viewer (user_id) VALUES (3), (4);

INSERT INTO Moderator (user_id) VALUES (5);

INSERT INTO ModeratorPermissionLevel (permission_id, user_id, permission_level) VALUES
  (1, 5, 'full');

INSERT INTO Video (video_id, user_id, views, like_count, dislike_count) VALUES
  (101, 1, 5000, 200, 5),
  (102, 1, 800, 40, 1),
  (201, 2, 12000, 900, 12);

INSERT INTO VideoSubtitle (subtitle_id, video_id, user_id, subtitle_text) VALUES
  (1, 101, 3, 'Welcome to this video!'),
  (2, 101, 4, '[music playing]');

INSERT INTO Comment (comment_id, video_id, user_id, `text`, `timestamp`) VALUES
  (1, 101, 3, 'Great explanation!', '2025-01-15 10:30:00'),
  (2, 101, 4, 'Thanks for uploading.', '2025-01-16 08:00:00'),
  (3, 201, 3, 'Subscribed!', '2025-01-17 12:00:00');

INSERT INTO SubscribesTo (user_id, creator_id) VALUES
  (3, 1),
  (3, 2),
  (4, 2);

INSERT INTO Stream (stream_id, user_id, title, started_at) VALUES
  (1, 1, 'Q&A Live', '2025-02-01 18:00:00'),
  (2, 2, 'Gameplay stream', '2025-02-02 20:00:00');
