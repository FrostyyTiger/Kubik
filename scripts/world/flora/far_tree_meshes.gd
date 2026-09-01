class_name FarTreeMeshes

## DELETED BY TREES V3 STAGE 7. This file is its own gravestone.
##
## It built the impostor ring's shapes: a six-sided cone and an octahedron
## until distance v2, then stacks of boxes at the same triangle scale - a
## stepped pyramid for a conifer, a bulging stepped crown for a broadleaf, a
## thin post for a snag. Nineteen meshes drew two thousand trees in seven draw
## calls, and for four epics that was the right answer.
##
## WHAT IT GOT RIGHT AND WHAT REPLACED IT. Its own header argued that at 150 m
## a tree is a dozen pixels tall, its silhouette survives that and its whorls do
## not - so choose by OUTLINE and spend no triangle that does not change one.
## That is correct and it is still correct. What changed is that Kubik now has
## the same tree at three resolutions from one grid, so the coarse rung IS the
## silhouette and there is nothing left for a second shape language to do
## (ruling 4: geometry all the way out, no cards).
##
## AND THE LESSON IT PAID FOR TWICE, kept because it is about taste rather than
## about cones: **the outline was right and the surface was from a different
## game.** A six-sided cone under flat shading gives big diamond facets, and the
## eye read diamonds where it expected steps - Marcel's "rhomboid", which is a
## precise word and not a vague one. Distance v2 fixed it by rebuilding the
## shapes out of boxes at the same triangle count. A far object has to be made
## of the same STUFF as the near one, not merely the same shape, and trees v3 is
## that argument taken to its end.
##
## `color_of_species()` WAS THE OTHER HALF. It pinned every impostor to
## `Block.color_of(row["leaves"])` - shade A, straight out of the block palette
## - precisely so a forest's far half could not be a different green from its
## near half and draw a circle on the hillside at the voxel radius. That pin
## died with the leaf blocks. `TreeModels.canopy_color()` replaces it, and near
## and far cannot drift any more for a stronger reason than the old one: they
## are the same mesh under the same table, so the drift MECHANISM is what got
## deleted rather than the drift.
##
## The class name survives as this note. Nothing calls it.
