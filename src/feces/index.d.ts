import { Entity, Query, World } from "@rbxts/jecs";

type Component<T = any> = Entity<T>;

type nilValue = {
  readonly _nominal_nil_value: unique symbol;
};

type deleteValue = {
  readonly _nominal_delete_value: unique symbol;
};

type PlayerObject = Player | Player[] | ((arg: Player) => boolean);

export declare type changes = Map<
  Component,
  Map<
    Player,
    { value: Map<Entity, any>; special: Map<Entity, deleteValue | nilValue> }
  >
>;

export declare type deletes = Map<Player, Entity>;

export declare type applyable = Map<
  Component,
  { value: Map<Entity, any>; special: Map<Entity, deleteValue | nilValue> }
> & { __d: Entity };

export declare function group(
  changes: changes,
  deletes?: deletes,
): Map<Player, applyable>;

export class feces {
  replicated: Entity;
  queries: {
    single: Query<[unknown]>;
    pair: Query<[unknown]>;
  };
  world: World;
  pendingChanges: changes;
  pendingDeletes: deletes;
  refs: { [S: string]: Entity };

  ref: (this: feces, key?: string) => Entity;
  replicating: (
    this: feces,
    callback: (
      component1: Component,
      playerObj: PlayerObject,
      entity: Entity,
      any: any,
      component2: Component,
    ) => void,
  ) => void;

  apply: (this: feces, apply: applyable) => void;
  delta: (this: feces) => LuaTuple<[changes, deletes]>;

  full: (this: feces) => applyable;
  group: (changes: changes, deletes?: deletes) => Map<Player, applyable>;

  added: (this: feces, callback: (entity: Entity) => void) => void;
  changed: (
    this: feces,
    callback: (entity: Entity, component: Entity, value: any) => void,
  ) => void;
  removed: (
    this: feces,
    callback: (entity: Entity, component: Component, value: any) => void,
  ) => void;
  deleted: (this: feces, callback: (entity: Entity) => void) => void;

  hooks: {
    added: (callback: (entity: Entity) => void) => void;
    changed: (
      callback: (entity: Entity, component: Entity, value: any) => void,
    ) => void;
    removed: (
      callback: (entity: Entity, component: Component, value: any) => void,
    ) => void;
    deleted: (entity: Entity, callback: (entity: Entity) => void) => void;
  };
}
