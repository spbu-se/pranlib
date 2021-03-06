(*
 * PathCovering: minimal path covering construction.
 * Copyright (C) 2004-2006
 * Dmitri Boulytchev, St.Petersburg State University
 * Oleg Medvedev, St.Petersburg State University
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License version 2, as published by the Free Software Foundation.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * See the GNU Library General Public License version 2 for more details
 * (enclosed in the file COPYING).
 *)

    
module Make 
    (D : DFST.Sig)
    (B : sig type edge val build : unit -> (edge list) end with type edge = D.G.Edge.t) =
  struct

    open List

    let data = lazy (B.build ())  

    let edges = Lazy.force data

    let nodes = lazy (
      let module NodeSet = Set.Make (D.G.Node) in
      let covered = List.fold_left (fun set e -> NodeSet.add (D.G.src e) (NodeSet.add (D.G.dst e) set)) NodeSet.empty edges in
      LOG (
        Printf.fprintf stderr "Covered node set:\n";
        NodeSet.iter (fun node -> Printf.fprintf stderr "%s; " (D.G.Node.toString node)) covered;
        Printf.fprintf stderr "\n";
      );
      List.filter 
      (fun node -> 
        LOG (Printf.fprintf stderr "Checking node %s\n" (D.G.Node.toString node)); 
        not (NodeSet.mem node covered)
      ) 
      (D.G.nodes D.graph) 
    )

    let _ = 
      LOG (
        Printf.fprintf stderr "Single node list:\n";
        List.iter (fun node -> Printf.fprintf stderr "%s; " (D.G.Node.toString node)) (Lazy.force nodes);
        Printf.fprintf stderr "\n";
      )
           
    let nodes () = Lazy.force nodes
    let edges () = edges
 
    let toDOT () =

      let module EdgeSet = Set.Make (D.G.Edge) in
      let module NodeSet = Set.Make (D.G.Node) in

      let edges = fold_left (fun set edge -> EdgeSet.add edge set) EdgeSet.empty (edges ()) in
      let nodes = fold_left (fun set node -> NodeSet.add node set) NodeSet.empty (nodes ()) in

      let module GInfo = Digraph.DotInfo
        (D.G)
        (
         struct
  
          include D.DOT.Node
  
          let attrs node = 
            if NodeSet.mem node nodes 
            then ("color", "magenta") :: (attrs node)
            else attrs node
  
         end
        )
        (struct
  
          include D.DOT.Edge
  
          let attrs edge = 
            if EdgeSet.mem edge edges 
            then map (function ("color", _) -> "color", "magenta" | x -> x ) (attrs edge)
            else attrs edge
  
         end
        )
      in
      let module P = DOT.Printer (GInfo) in
        P.toDOT D.graph

    type path = Single of D.G.Node.t | Path of (D.G.Node.t * D.G.Edge.t) list * D.G.Node.t

    let paths () =

      let module NodeSet = Set.Make (D.G.Node) in
      let module NodeMap = Map.Make (D.G.Node) in

      let edges = edges () in
      let check set elt num = if NodeSet.mem elt set then num else 0 in
      let heads, tails, path = 
	fold_left 
	  (fun (heads, tails, path) edge ->
            let src, dst = D.G.src edge, D.G.dst edge in
            let path = NodeMap.add src edge path in
            match (check tails src 1) + (check heads dst 2) with
            | 0 (* not tail, not head *) -> NodeSet.add src heads, NodeSet.add dst tails, path
            | 1 (* src is tail *)        -> heads, NodeSet.add dst (NodeSet.remove src tails), path
            | 2 (* dst is head *)        -> NodeSet.add src (NodeSet.remove dst heads), tails, path
            | 3 (* both        *)        -> NodeSet.remove dst heads, NodeSet.remove src tails, path
	  )   
	  (NodeSet.empty, NodeSet.empty, NodeMap.empty)
          edges
      in
      (NodeSet.fold 
	 (fun head fragments -> 
	   let rec build node list =
             if NodeSet.mem node tails then list, node
             else 
               let edge = NodeMap.find node path in
               build (D.G.dst edge) ((node, edge) :: list)
	   in
	   let list, last = build head [] in
	   (Path (rev list, last)) :: fragments
	 ) 
	 heads 
	 []) @ (List.map (fun node -> Single node) (nodes ()))
		 
  end
    
module MakeBuildWeighted 
    (T     : DFST.Sig)
    (Freqs : sig type t val w : t -> int end with type t = T.G.Edge.info) = 
  struct
    
    module WeightedGraph = 
      struct
	
	type t = int * int * (((int * int) * int) Urray.t)
    
	let nBoys (n, _, _) = n
	let nGirls(_, m, _) = m
	let edges (_, _, es) = es
	    
      end

    type edge = T.G.Edge.t
	  
    let build () =
      let graph = T.graph in
      let start = T.start in
    
      let eh = Hashtbl.create (T.G.nedges graph) in
      let n = T.G.nnodes graph in
      let edges = T.G.edges graph in
      let numbering = T.Pre.number in
      let numbering' = T.Pre.node in
    
      let bipartEdges = 
	List.fold_left
          (fun res edge ->
            match T.sort edge with
            | DFST.Back -> res
            | _ ->
		let n = numbering (T.G.src edge) in
		let k = numbering (T.G.dst edge) in
		Hashtbl.add eh (n, k) edge;
		((n, k), Freqs.w (T.G.Edge.info edge)) :: res
          )
          []
          edges
      in
      let wg = n, n, (Urray.of_list bipartEdges) in
      let module P = PairMatching.Make(WeightedGraph) in
      let matching = P.search wg in
      let ans = List.map (fun (e, w) -> Hashtbl.find eh e) matching in
      let module X = View.List(T.G.Edge) in

      LOG (Printf.fprintf stderr "%s\n" (X.toString ans));

      ans
    
  end

module MakeBuildSimple (D : DFST.Sig) = MakeBuildWeighted (D) (struct type t = D.G.Edge.info let w _ = 1 end)

module MakeSimple (D : DFST.Sig) = Make(D)(MakeBuildSimple(D))
      
module MakeWeighted 
    (D : DFST.Sig)
    (Freqs : sig type t val w : t -> int end with type t = D.G.Edge.info) = 
  Make(D)(MakeBuildWeighted(D)(Freqs))
