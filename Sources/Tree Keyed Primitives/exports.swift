// exports.swift
// Re-export dependencies for consumers.
//
// The keyed tree surfaces `Tree` / `Tree.Position` (the shared `Tree.Storage`
// engine) and constrains its key on `Hash.Protocol`; the keyed-children column
// vocabulary (`Dictionary.Ordered` / `Hash.Indexed` / `Column.Heap` / `Shared` /
// `Store.Generational.Handle`) is now an INTERNAL detail of `__TreeKeyedLinks`, but
// the full spelling set is re-exported for consumer convenience alongside the
// tree core.

@_exported public import Dictionary_Primitive
@_exported public import Dictionary_Ordered_Primitive
@_exported public import Dictionary_Ordered_Primitives
@_exported public import Hash_Primitives
@_exported public import Hash_Indexed_Primitive
@_exported public import Column_Primitives
@_exported public import Buffer_Linear_Primitive
@_exported public import Shared_Primitive
@_exported public import Store_Primitive
@_exported public import Storage_Generational_Primitives
@_exported public import Tree_Primitives
