# Duplex


Duplex is a reactive graph built from two paired strands: value dependencies and dirty propagation.

```
  Node(parent) --ref-> Node(child1) --ref-> Node(child2)
      |                    |                    |
     ref                  ref                  ref
      |                    |                    |
      v                    v                    v
 Dirty(parent) <-ref-- Dirty(child) <-ref-- Dirty(child2)
```