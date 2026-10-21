#!/bin/sh
# Rebuilds every capsule_63 still, one headless Chrome at a time. Run from docs/art/mockups.
c() { sh capsule_63_src/cap.sh "$1" "cap=1&$2" "$3"; }
for L in a b c; do
  c capsule_63_$L.html "" capsule_63_${L}_choose_1920x1080.png
  c capsule_63_$L.html "state=full" capsule_63_${L}_full_1920x1080.png
  c capsule_63_$L.html "nosave=1" capsule_63_${L}_nosave_1920x1080.png
  c capsule_63_$L.html "coins=0" capsule_63_${L}_nocoins_1920x1080.png
done
for t in 0.3 0.75 1.2 1.6 2.15 3; do c capsule_63_a.html "draw=5&t=$t" capsule_63_a_draw_at$t.png; done
c capsule_63_a.html "draw=5&t=1&rm=1" capsule_63_a_draw_rm.png
c capsule_63_a.html "words=capsule" capsule_63_a_capsule_wording_1920x1080.png
for t in 0.6 1.6 3; do c capsule_63_b.html "draw=3&t=$t" capsule_63_b_draw_at$t.png; done
c capsule_63_b.html "draw=3&t=1&rm=1" capsule_63_b_draw_rm.png
for t in 0.75 1.6 3; do c capsule_63_c.html "draw=5&t=$t" capsule_63_c_draw_at$t.png; done
c capsule_63_c.html "draw=5&t=3&land=0.25" capsule_63_c_land_mid.png
c capsule_63_c.html "draw=5&t=3&land=1" capsule_63_c_land_done.png
c capsule_63_c.html "draw=5&t=1&rm=1" capsule_63_c_draw_rm.png
c capsule_63_c.html "locked=hidden" capsule_63_c_hidden_1920x1080.png
c capsule_63_shelf.html "state=partial&hover=Strawberries" capsule_63_shelf_partial_1920x1080.png
c capsule_63_shelf.html "state=partial&locked=spaces" capsule_63_shelf_partial_spaces_1920x1080.png
c capsule_63_shelf.html "state=full" capsule_63_shelf_full_1920x1080.png
c capsule_63_shelf.html "state=full&labels=1" capsule_63_shelf_full_labels_1920x1080.png
c capsule_63_shelf.html "state=fresh" capsule_63_shelf_fresh_1920x1080.png
c capsule_63_index.html "" capsule_63_index_1920x1080.png
