-- Starter prompt deck (docs/PRODUCT.md §6.3). Hand-authored, tone-tagged, behavior-only (obeys
-- the bright lines). `display_order` controls rotation sequencing (migration 0011/0014) so the
-- deck can be edited/extended without re-basing everyone; publish_date null (rotation is a pure
-- function of profile+day). Tuned per the 2026-06-17 audit: 8 wholesome (was 4), spicy prompts
-- re-aimed onto behavior, and competence / one-on-one / aesthetic axes added.
-- NOTE: this seed defines the deck for a FRESH database; the live deck delta lives in migration 0014.
insert into public.prompts (text, tone, display_order) values
  ('What''s your favorite memory of them?',                                            'wholesome', 1),
  ('What''s a small thing they do that they think nobody clocks?',                      'wholesome', 2),
  ('When have they really shown up for you?',                                           'wholesome', 3),
  ('What do they always make better just by being there?',                             'wholesome', 4),
  ('What do you always end up doing when it''s just the two of you?',                   'wholesome', 5),
  ('What''s a small thing they do that always makes your day better?',                  'wholesome', 6),
  ('When did you first realize they were one of your people?',                          'wholesome', 7),
  ('What''s the kindest thing you''ve seen them do when no one was keeping score?',      'wholesome', 8),

  ('Describe them as a Sims character.',                                                'playful',   9),
  ('What would they bring to the apocalypse?',                                          'playful',  10),
  ('If they were a kitchen appliance, which one and why?',                              'playful',  11),
  ('What''s their villain origin story?',                                               'playful',  12),
  ('Cast them in a movie — what role?',                                                 'playful',  13),
  ('What''s their signature order, outfit, or detail — the most "them" thing?',         'playful',  14),
  ('If their life had a theme song right now, what''s playing?',                        'playful',  15),

  ('How are they socially?',                                                            'social',   16),
  ('What''s their role in the group chat?',                                             'social',   17),
  ('What''s their most "them" habit?',                                                  'social',   18),
  ('How do they act when the plan falls apart?',                                        'social',   19),
  ('What''s the running joke about them?',                                              'social',   20),
  ('What are they weirdly, specifically good at?',                                      'social',   21),
  ('What''s the face they make that always gives them away?',                          'social',   22),

  ('What''s the thing they do that drives everyone a little insane?',                   'spicy',    23),
  ('Roast them in one sentence.',                                                       'spicy',    24),
  ('What''s the habit they''ll defend to their grave?',                                 'spicy',    25),
  ('What''s the most chaotic thing they do?',                                           'spicy',    26),
  ('Where are they always, predictably, wrong?',                                        'spicy',    27)
on conflict do nothing;
