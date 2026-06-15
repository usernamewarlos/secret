-- Starter prompt deck (docs/PRODUCT.md §6.3). Hand-authored, tone-tagged, publish_date null
-- (the publish-daily-prompt function assigns dates). Obeys the bright lines: behavior/quirks only.
insert into public.prompts (text, tone) values
  ('What''s your favorite memory of them?', 'wholesome'),
  ('What''s something they''d be quietly proud you noticed?', 'wholesome'),
  ('When have they really shown up for you?', 'wholesome'),
  ('What do they always make better just by being there?', 'wholesome'),

  ('Describe them as a Sims character.', 'playful'),
  ('What would they bring to the apocalypse?', 'playful'),
  ('If they were a kitchen appliance, which one and why?', 'playful'),
  ('What''s their villain origin story?', 'playful'),
  ('Cast them in a movie — what role?', 'playful'),

  ('How are they socially?', 'social'),
  ('What''s their role in the group chat?', 'social'),
  ('What''s their most "them" habit?', 'social'),
  ('How do they act when the plan falls apart?', 'social'),
  ('What''s the running joke about them?', 'social'),

  ('What''s their biggest flaw?', 'spicy'),
  ('Roast them in one sentence.', 'spicy'),
  ('What do they need to hear but won''t?', 'spicy'),
  ('What''s the most chaotic thing they do?', 'spicy'),
  ('Where are they always, predictably, wrong?', 'spicy')
on conflict do nothing;
