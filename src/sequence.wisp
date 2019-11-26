(ns wisp.sequence
  (:require [wisp.runtime :refer [nil? vector? fn? number? string? dictionary?
                                  key-values str int dec inc min merge dictionary
                                  iterable? =]]))

;; Implementation of list

(defn- List
  "List type"
  [head tail]
  (set! this.head head)
  (set! this.tail (or tail (list)))
  (set! this.length (inc (count this.tail)))
  this)

(set! List.prototype.length 0)
(set! List.type "wisp.list")
(set! List.prototype.type List.type)
(set! List.prototype.tail (Object.create List.prototype))
(set! List.prototype.to-string
      (fn []
        (loop [result ""
               list this]
          (if (empty? list)
            (str "(" (.substr result 1) ")")
            (recur
             (str result
                  " "
                  (if (vector? (first list))
                    (str "[" (.join (first list) " ") "]")
                    (if (nil? (first list))
                      "nil"
                      (if (string? (first list))
                        (.stringify JSON (first list))
                        (if (number? (first list))
                          (.stringify JSON (first list))
                          (first list))))))
             (rest list))))))

(defn- lazy-seq-value [lazy-seq]
  (if (not (.-realized lazy-seq))
    (and (set! (.-realized lazy-seq) true)
         (set! (.-x lazy-seq) (.x lazy-seq)))
    (.-x lazy-seq)))

(defn- LazySeq [realized x]
  (set! (.-realized this) (or realized false))
  (set! (.-x this) x)
  this)
(set! LazySeq.type "wisp.lazy.seq")
(set! LazySeq.prototype.type LazySeq.type)

(defn lazy-seq
  [realized body]
  (LazySeq. realized body))

(defn lazy-seq?
  [value]
  (and value (identical? LazySeq.type value.type)))

(defn list?
  "Returns true if list"
  [value]
  (and value (identical? List.type value.type)))

(defn list
  "Creates list of the given items"
  []
  (if (identical? (.-length arguments) 0)
    (Object.create List.prototype)
    (.reduce-right (.call Array.prototype.slice arguments)
                   (fn [tail head] (cons head tail))
                   (list))))

(defn cons
  "Creates list with `head` as first item and `tail` as rest"
  [head tail]
  (new List head tail))

(defn ^boolean sequential?
  "Returns true if coll satisfies ISequential"
  [x] (or (list? x)
          (vector? x)
          (lazy-seq? x)
          (dictionary? x)
          (string? x)))

(defn- ^boolean native? [sequence]
  (or (vector? sequence) (string? sequence) (dictionary? sequence)))


(defn reverse
  "Reverse order of items in the sequence"
  [sequence]
  (if (vector? sequence)
    (.reverse (vec sequence))
    (into nil sequence)))

(defn range
  "Returns a vector of nums from start (inclusive) to end
  (exclusive), by step, where start defaults to 0 and step to 1."
  ([end]            (range 0 end 1))
  ([start end]      (range start end 1))
  ([start end step] (if (< step 0)
                      (.map (range (- start) (- end) (- step)) #(- %))
                      (Array.from {:length (-> (+ end step) (- start 1) (/ step))}
                                  (fn [_ i] (+ start (* i step)))))))

(defn mapv
  "Returns a vector consisting of the result of applying `f` to the
  first items, followed by applying f to the second items, until one of
  sequences is exhausted."
  [f & sequences]
  (let [vectors (.map sequences vec),  n (apply min (.map vectors count))]
    (.map (range n) (fn [i] (apply f (.map vectors #(aget % i)))))))

(defn map
  "Returns a sequence consisting of the result of applying `f` to the
  first items, followed by applying f to the second items, until one of
  sequences is exhausted."
  [f & sequences]
  (let [result (apply mapv f sequences)]
    (if (native? (first sequences)) result (apply list result))))

(defn map-indexed
  "Returns a sequence consisting of the result of applying `f` to 0 and
  the first items, followed by applying f to 1 and the second items,
  until one of sequences is exhausted."
  [f & sequences]
  (let [sequence (first sequences),  n (count sequence),  indices (range n)]
    (apply map f (if (native? sequence) indices (apply list indices)) sequences)))

(defn filter
  "Returns a sequence of the items in coll for which (f? item) returns true.
  f? must be free of side-effects."
  [f? sequence]
  (cond (vector? sequence) (.filter sequence f?)
        (list? sequence) (filter-list f? sequence)
        (nil? sequence) '()
        :else (filter f? (seq sequence))))

(defn- filter-list
  "Like filter but for lists"
  [f? sequence]
  (loop [result '()
         items sequence]
    (if (empty? items)
      (reverse result)
      (recur (if (f? (first items))
               (cons (first items) result)
               result)
             (rest items)))))

(defn filterv [f? sequence]
  (vec (filter f? sequence)))

(defn reduce
  [f & params]
  (let [has-initial (>= (count params) 2)
        initial (if has-initial (first params))
        sequence (if has-initial (second params) (first params))]
    (cond (nil? sequence) initial
          (vector? sequence) (if has-initial
                              (.reduce sequence f initial)
                              (.reduce sequence f))
          (list? sequence) (if has-initial
                            (reduce-list f initial sequence)
                            (reduce-list f (first sequence) (rest sequence)))
          :else (reduce f initial (seq sequence)))))

(defn- reduce-list
  [f initial sequence]
  (loop [result initial
         items sequence]
    (if (empty? items)
      result
      (recur (f result (first items)) (rest items)))))

(defn count
  "Returns number of elements in list"
  [sequence]
  (let [it (seq sequence)]
    (cond (nil? it)      0
          (lazy-seq? it) (inc (count (rest it)))
          :else          (.-length it))))

(defn empty?
  "Returns true if list is empty"
  [sequence]
  (identical? (count sequence) 0))

(defn first
  "Return first item in a list"
  [sequence]
  (cond (nil? sequence) nil
        (list? sequence) (.-head sequence)
        (or (vector? sequence) (string? sequence)) (get sequence 0)
        (lazy-seq? sequence) (first (lazy-seq-value sequence))
        :else (first (seq sequence))))

(defn second
  "Returns second item of the list"
  [sequence]
  (cond (nil? sequence) nil
        (list? sequence) (first (rest sequence))
        (or (vector? sequence) (string? sequence)) (get sequence 1)
        (lazy-seq? sequence) (second (lazy-seq-value sequence))
        :else (first (rest (seq sequence)))))

(defn third
  "Returns third item of the list"
  [sequence]
  (cond (nil? sequence) nil
        (list? sequence) (first (rest (rest sequence)))
        (or (vector? sequence) (string? sequence)) (get sequence 2)
        (lazy-seq? sequence) (third (lazy-seq-value sequence))
        :else (second (rest (seq sequence)))))

(defn rest
  "Returns list of all items except first one"
  [sequence]
  (cond (nil? sequence) '()
        (list? sequence) (.-tail sequence)
        (or (vector? sequence) (string? sequence)) (.slice sequence 1)
        (lazy-seq? sequence) (rest (lazy-seq-value sequence))
        :else (rest (seq sequence))))

(defn- last-of-list
  [list]
  (loop [item (first list)
         items (rest list)]
    (if (empty? items)
      item
      (recur (first items) (rest items)))))

(defn last
  "Return the last item in coll, in linear time"
  [sequence]
  (cond (or (vector? sequence)
            (string? sequence)) (get sequence (dec (count sequence)))
        (list? sequence) (last-of-list sequence)
        (nil? sequence) nil
        (lazy-seq? sequence) (last (lazy-seq-value sequence))
        :else (last (seq sequence))))

(defn butlast
  "Return a seq of all but the last item in coll, in linear time"
  [sequence]
  (let [items (cond (nil? sequence) nil
                    (string? sequence) (subs sequence 0 (dec (count sequence)))
                    (vector? sequence) (.slice sequence 0 (dec (count sequence)))
                    (list? sequence) (apply list (butlast (vec sequence)))
                    (lazy-seq? sequence) (butlast (lazy-seq-value sequence))
                    :else (butlast (seq sequence)))]
    (if (not (or (nil? items) (empty? items)))
        items)))

(defn take
  "Returns a sequence of the first `n` items, or all items if
  there are fewer than `n`."
  [n sequence]
  (cond (nil? sequence) '()
        (vector? sequence) (take-from-vector n sequence)
        (list? sequence) (take-from-list n sequence)
        (lazy-seq? sequence) (take n (lazy-seq-value sequence))
        :else (take n (seq sequence))))

(defn- take-vector-while
  [predicate vector]
  (loop [vector vector, result []]
    (let [head (first vector), tail (rest vector)]
      (if (and (not (empty? vector))
               (predicate head))
        (recur tail (conj result head))
        result))))

(defn take-while
  [predicate sequence]
  (cond (nil? sequence) '()
        (vector? sequence) (take-vector-while predicate sequence)
        (list? sequence) (take-vector-while predicate sequence)
        :else (take-while predicate
                          (lazy-seq-value sequence))))


(defn- take-from-vector
  "Like take but optimized for vectors"
  [n vector]
  (.slice vector 0 n))

(defn- take-from-list
  "Like take but for lists"
  [n sequence]
  (loop [taken '()
         items sequence
         n n]
    (if (or (identical? n 0) (empty? items))
      (reverse taken)
      (recur (cons (first items) taken)
             (rest items)
             (dec n)))))




(defn- drop-from-list [n sequence]
  (loop [left n
         items sequence]
    (if (or (< left 1) (empty? items))
      items
      (recur (dec left) (rest items)))))

(defn drop
  [n sequence]
  (if (<= n 0)
    sequence
    (cond (string? sequence) (.substr sequence n)
          (vector? sequence) (.slice sequence n)
          (list? sequence) (drop-from-list n sequence)
          (nil? sequence) '()
          (lazy-seq? sequence) (drop n (lazy-seq-value sequence))
          :else (drop n (seq sequence)))))

(defn drop-while
  [predicate sequence]
  (loop [items (seq sequence)]
    (if (or (empty? items) (not (predicate (first items))))
      items
      (recur (rest items)))))


(defn- conj-list
  [sequence items]
  (reduce (fn [result item] (cons item result)) sequence items))

(defn- ensure-dictionary [x]
  (if (not (vector? x))
    x
    (dictionary (first x) (second x))))

(defn conj
  [sequence & items]
  (cond (vector? sequence) (.concat sequence items)
        (string? sequence) (str sequence (apply str items))
        (nil? sequence) (apply list (reverse items))
        (or (list? sequence)
            (lazy-seq?)) (conj-list sequence items)
        (dictionary? sequence) (merge sequence (apply merge (mapv ensure-dictionary items)))
        :else (throw (TypeError (str "Type can't be conjoined " sequence)))))

(defn into
  [to from]
  (apply conj to (vec from)))

(defn assoc
  [source & key-values]
  ;(assert (even? (count key-values)) "Wrong number of arguments")
  ;(assert (and (not (seq? source))
  ;             (not (vector? source))
  ;             (object? source)) "Can only assoc on dictionaries")
  (conj source (apply dictionary key-values)))

(defn concat
  "Returns list representing the concatenation of the elements in the
  supplied lists."
  [& sequences]
  (reverse
    (reduce
      (fn [result sequence]
        (reduce
          (fn [result item] (cons item result))
          result
          (seq sequence)))
      '()
      sequences)))

(defn mapcat [f sequence]
  (apply concat (mapv f sequence)))

(defn seq [sequence]
  (cond (nil? sequence) nil
        (or (vector? sequence) (list? sequence) (lazy-seq? sequence)) sequence
        (string? sequence) (.call Array.prototype.slice sequence)
        (dictionary? sequence) (key-values sequence)
        (iterable? sequence) (iterator->lseq ((get sequence Symbol.iterator)))
        :default (throw (TypeError (str "Can not seq " sequence)))))

(defn seq? [sequence]
  (or (list? sequence)
      (lazy-seq? sequence)))

(defn- iterator->lseq [iterator]
  (let [x (.next iterator)]
    (if (not (.-done x))
      (lazy-seq (cons (.-value x) (iterator->lseq iterator))))))

(defn- list->vector [source]
  (loop [result []
         list source]
    (if (empty? list)
      result
      (recur
        (do (.push result (first list)) result)
        (rest list)))))

(defn vec
  "Creates a new vector containing the contents of sequence"
  [sequence]
  (cond (nil? sequence) []
        (vector? sequence) (Array.from sequence)
        (or (list? sequence) (lazy-seq? sequence)) (list->vector sequence)
        :else (vec (seq sequence))))

(defn vector [& sequence] sequence)

(def ^{:private true}
  sort-comparator
  (if (= [1 2 3] (.sort [2 1 3] (fn [a b] (if (< a b) 0 1))))
    #(fn [a b] (if (% b a)  1 0))       ; quicksort (Chrome, Node), mergesort (Firefox)
    #(fn [a b] (if (% a b) -1 0))))     ; timsort (Chrome 70+, Node 11+)

(defn sort
  "Returns a sorted sequence of the items in coll.
  If no comparator is supplied, uses compare."
  [f items]
  (let [has-comparator (fn? f)
        items          (if (and (not has-comparator) (nil? items)) f items)
        compare        (if has-comparator (sort-comparator f))
        result         (.sort (vec items) compare)]
    (cond (nil? items)    '()
          (vector? items) result
          :else           (apply list result))))


(defn repeat
  "Returns a vector of given `n` length with of given `x`
  items. Not compatible with clojure as it's not a lazy
  and only finite repeats are supported"
  [n x]
  (loop [n      (int n)
         result []]
    (if (<= n 0)
      result
      (recur (dec n)
             (conj result x)))))

(defn every?
  [predicate sequence]
  (.every (vec sequence) #(predicate %)))

(defn some
  "Returns the first logical true value of (pred x) for any x in coll,
  else nil.  One common idiom is to use a set as pred, for example
  this will return :fred if :fred is in the sequence, otherwise nil:
  (some #{:fred} coll)      ; Clojure sets aren't implemented"
  [pred coll]
  (loop [items (seq coll)]
    (if (not (empty? items))
      (or (pred (first items)) (recur (rest items))))))


(defn partition
  ([n coll] (partition n n coll))
  ([n step coll] (partition n step [] coll))
  ([n step pad coll]
   (loop [result []
          items (seq coll)]
     (let [chunk (take n items)
           size (count chunk)]
       (cond (identical? size n) (recur (conj result chunk)
                                        (drop step items))
             (identical? 0 size) result
             (> n (+ size (count pad))) result
             :else (conj result
                         (take n (vec (concat chunk
                                              pad)))))))))

(defn interleave [& sequences]
  (if (empty? sequences)
    []
    (loop [result []
           sequences sequences]
      (if (some empty? sequences)
        (vec result)
        (recur (concat result (map first sequences))
               (map rest sequences))))))

(defn nth
  "Returns nth item of the sequence"
  [sequence index not-found]
  (cond (nil? sequence) not-found
        (list? sequence) (if (< index (count sequence))
                           (first (drop index sequence))
                           not-found)
        (or (vector? sequence)
            (string? sequence)) (if (< index (count sequence))
                                  (aget sequence index)
                                  not-found)
        (lazy-seq? sequence) (nth (lazy-seq-value sequence) index not-found)
        :else (throw (TypeError "Unsupported type"))))
