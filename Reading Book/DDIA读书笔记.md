
---
annotation-target: file://D:\BaiduNetdiskDownload\ddia.pdf
---


>%%
>```annotation-json
>{"created":"2023-08-01T01:30:08.889Z","updated":"2023-08-01T01:30:08.889Z","document":{"title":"Designing Data-Intensive Applications","link":[{"href":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630"}],"documentFingerprint":"f4030ab3256cbd6de727d8a4f1de8630"},"uri":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630","target":[{"source":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630","selector":[{"type":"TextPositionSelector","start":488651,"end":488678},{"type":"TextQuoteSelector","exact":"Partitioning by Hash of Key","prefix":"ange query for each sensor name.","suffix":"Because  of  this  risk  of  ske"}]}]}
>```
>%%
>*%%PREFIX%%ange query for each sensor name.%%HIGHLIGHT%% ==Partitioning by Hash of Key== %%POSTFIX%%Because  of  this  risk  of  ske*
>%%LINK%%[[#^setm1v4msw|show annotation]]
>%%COMMENT%%
>
>%%TAGS%%
>
^setm1v4msw

## Partitioning
### Partitioning and Secondary Indexes
The partitioning schemas we have discussed so far rely on a key-value data model.
The situation becomes more complicated if secondary indexes are involved (see also "Other Indexing Structures" on page 85). A secondary index usually doesn't indentify a record uniquely but rather is a way of searching for occurrences of a particular value: find all actions by user 123, find all articles containing the world bogwash, find all cars whose color is red, and so on.

Secondary indexes are the bread and butter of relational databases, and they are common in document databases too. Many key-value stores (such as HBase and Voldemort) have avoided secondary indexes because of their added implementation complexity, but some (such as Riak) have started adding them because they are so useful for data modeling. And finally, secondary indexes are the rasion detre of search servers such as Solr and Elasticsearch.
The problem with secondary indexes is that they don't map neatly to partitions. There are two main approaches to partitioning a database with secondary indexes: document-based partitioning and term-based partitionning.

### Partiion Secondary Indexes by Document
For example, imagine you are operating a website for selling used cars(illustrated in Figure 6-4). Each listing has a unique ID --- call it the document ID -- and you partion the database by the document ID (for example, IDs 0 to 499 in partition 0, IDs 500 to 999 in partition 1, etc.).

If you have decalared the index, the database can perform the indexing automatically. For example, whenever a red car is added to the database, the database partition automatically adds it to the list of document IDs for the index entry color:red.

In this indexing approach, each partition is completely separate: each partition maintains its own secondary indexes, covering only the documents in that partition. It doesn't care what data is stored in other partitions. Whenever you need to write to the database -- to add, remove, or update a document -- you only need to deal with the partition that contains the document ID that you are writing. For that reason, a document-partitioned index is also known as a local index (as opposed to a global index, described in the next section).

### Partitioning Secondary Indexes by Term
Rantehr than each partition having its own secondary index (a local index), we can construct a global index that covers data in all partitions. However, we can't just store that index on one node, since it would likely become a bottleneck and defeat the purpose of partitioning. A global index must also be partioned, but it can be partitioned differently from the primary key index.

### Rebalancing Partitions
Over time, things change in a database:
- The query throughput increases, so you want to add more CPUs to handle the load.
- The dataset size increases, so you want to add more disks and RAM to srotre it.
- A machine fails, and other machines need to take over the failed machine's responsibilities.

All of these changes call for data and requests to be moved from one node to another. The process of moving load from one node in the cluster to another is called rebalacing.
No matter which partitioning scheme is used, rebalancing is usually expected to meet some minimum requirements:
- After reblancing, the load (data storage, read and write requests) should be shared fairly bewteen the nodes in the cluster.
- While rebalancing is happening, the database should continue accepting reads and writes.
- No more data than neccessary should be moved between nodes, to make rebalancing fast and to minize the network and disk I/O load.

### Strategies for Rebalancing
There are a few different ways of assigning partitions to nodes. Let's briefly discuss each in turn.

>%%
>```annotation-json
>{"created":"2023-08-01T08:04:14.144Z","text":"Strategies for Rebalancing","updated":"2023-08-01T08:04:14.144Z","document":{"title":"Designing Data-Intensive Applications","link":[{"href":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630"}],"documentFingerprint":"f4030ab3256cbd6de727d8a4f1de8630"},"uri":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630","target":[{"source":"urn:x-pdf:f4030ab3256cbd6de727d8a4f1de8630","selector":[{"type":"TextPositionSelector","start":503836,"end":503862},{"type":"TextQuoteSelector","exact":"Strategies for Rebalancing","prefix":"oad.Rebalancing Partitions | 209","suffix":"There are a few different ways o"}]}]}
>```
>%%
>*%%PREFIX%%oad.Rebalancing Partitions | 209%%HIGHLIGHT%% ==Strategies for Rebalancing== %%POSTFIX%%There are a few different ways o*
>%%LINK%%[[#^5wur6sxuh8k|show annotation]]
>%%COMMENT%%
>Strategies for Rebalancing
>%%TAGS%%
>
^5wur6sxuh8k
#### How not to do it: hash mod N
> Drawback: The mod N approach is that if the number of nodes N changes, most of the keys will need to moved from one node to another. Such frequent moves make rebalancing excessively expensive.

#### Fixed number of partitions
Only entire partitions are moved between nodes. The number of partitions does not change, nor does the assignment of keys to partitions.
> Drawback: Choosing the right number of partitions is difficult if the total size of dataset is highly variable.
> The best performance is achieved when the size of partitions is "just right", neither too big nor too small, which can be hard to achieve if the number of partitions is fixed but the dataset size varies.

#### Dynamic partitioning
> Dynnamic partitioning is not only suitable for key range-partitioned data, but can equally well be used with hash-partitioned data.

#### Partitioning proportionally to nodes
To have a fixed number of partitions per node. 
> Picking partition boundaries randomly requires that hash-based partitioning is used (so the boundraries can be picked from the range of numbers produced by the hash function). Indeed, this approach correponds most closely to the original definition of consistent hashing (see "Consistent Hasing"). Newer hash functions can achieve a similar effect with lower metadata overhead.

### Operations: Automatic or Manual Rebalancing

### Request Routing
This is an instance of a more general problem called service discovery.
On a high level, there are a few different approaches to this problem (illustrated in Figure 6-7):
1. Allow clients to contact any node (e.g., via a round-robin balancer). If that node coincidentally owns the partion to which the request applies, it can handle the request directly; otherwise, it forwards the request to the appropriate node, receives the reply, and passes the reply along the client.
2. Send all requests from clients to a routing tier first, which determines the node that should handle each request and forwards it accordingly. This routing tier does not itself handle any request; it noly acts as a partition-aware load balancer.
3. Require that clients be aware of the partitioning and the assignment of partitions to nodes. In this case, a client can connect directly to the appropriate node, without any intermeditely.

### Parallel Query Execution

### Summary
In thie chapter we explored different ways of partitioning a large dataset into smaller subsets. Partitioning is neccessary when you have so much data that storing and processing it on a single machine is no longer feasible.
The goal of partitioning is to spread the data and query load evenly across multiple machines, avoiding hot spots (nodes with disproportionately high load). This requires choosing a partitioning scheme that is appropriate to your data, and rebalancing the partitions when nodes are added to or removed from the cluster.
We discussed two main approaches to partitioning:
- Key range partitioning(Sorting has the advantage that efficient range queries are possible, but there is a risk of hot spots if the application often accesses keys that are close together in the sorted order).
- Hash partitioning(This method destroy the ordering of keys, making range queires inefficient, but may distribute load more evenly).
Hybird approaches are also possible, for example with a compound key: using one part of the key to identify the partition an another part of the sort order.
We also discussed the interaction between partitioning and secondary indexes. A secondary index also needs to be partitioned, and there are two methods:
- Document-partitioned indexes (local indexes), where the secondary indexes are stored in the same partition as the primary key and value.This means that only a single partition needs to be updated on write, but a read of the secondary index requires a scatter/gather across all partitions.![[Pasted image 20230802110442.png]]
- Term-partitioned indexes (gloabal indexes), where the secondary indexes are partitioned separately, using the indexed values. An entry in the secondary index may include records from all partitions of the primary key. When a document is writen, several partitions of the secondary index need to be updated; however, a read can be seved from a single partion.![[Pasted image 20230802110555.png]]

## Transactions
> A transaction is a way for an application to group several reads and writes together into a logical unit. Conceptually, all the reads and writes in a transaction are executed as one operation: either the entire transaction succeeds (commit) or it fails (abort, rollback).

This chapter applies to both single-node and distributed databases; in Chapter 8 we will focus the discussion on the particular challenges that arise only in distributed systems.
### The Slippery Concept of a Transaction
### The Meaning of ACID
### Atomicity
The ability to abort a transaction on error and have all writes from that transaction discarded is the defining feature of ACID atomicity. Perhaps abortability would have been a better term than atomicity, but we will stick with atomicity since that's the usual word.
### Consistency
The word consistency is terribly overloaded:
- In [[Chapter 5]] we disscussed replica consistency and the issue of eventual consistency that arises in asynchronously replicated system.
- Consistent hasing is an approach to partitioning that some systems use for rebalancing.
- In the CAP theorem (see [[Chapter 9]]), the word consistency is used to mean linearizability.
- In the context of ACID, consistency refers to an application-specific notion of the database being in a "good state".
### Isolation
Most databases are accessed by several clients at the same time. That is no problem if they reading and writing different parts of the database, but if they are accessing the same database records, you can run into concurrency problems (race conditions).
### Durability
The purpose of a database system is to provide a safe place where data can be stored without fear of losing it. Durability is the promise that once a transaction has committed successfully, any data it has written will not be forgotten, even if there is a hardware fault or the database crashes.
In a single-node database, durability typically means that the data has 
In an asynchronously replicated system, recent writes may be lost when the leader becomes unavailable (see "Handling Node Outages" on page 156).

In practice, there is no one technique that can provide absolute guarantees. There are only various risk-reduction techniques, including writing to disk, replicating to remote machines, and backups--and they can should be used together. As always, it's wise to take any theoretical "guarantees" with a healthy grain of salt.

### Single-Object and Multi-Object Operations
Such multi-object transactions are often needed if several pieces of data need to be kept in sync.
Figure 7-3 illustrates the need for atomicity: if an error occurs somewhere over the course of the transaction, the contents of the mailbox and the unread counter might become out of sync. In an atomic transaction, if the update to the counter fails, the transaction is aborted and the inserted email is rolled back.
#### Single-object writes
Similarly popular is a compare-and-set operation, which allows a write to happen only if the value has not been concurrently changed by someone else(see [[Compare-and-set]])
#### The need for multi-object transactions
Such applications can still be implemented without transactions. However, error handling becomes much more complicated without atomicity, and the lack of isolation can cause concurrency problems. We will discuss those in "[[Weak Isolation Levels]]", and explore alternative approaches in [[Chapter 12]].

### Handling errors and aborts
A key feature of a transaction is that it can be aborted and safely retried if an error occurred. ACID databases are based on this philosophy: if the database is in danger of violating its guarantee of atomicity, isolation, or durability, it would rather abandon the transaction entirely than allow it to remain half-finished.
In particular, databases with leaderless replication work much more on a "best effort" basis. -- so it's the application's responsibility to recover from errors.

### Weak Isolation Levels
Concurrency bugs are hard to find by testing, because such bugs are only triggered when you get unlucky with the timing. 
### Read Committed
The most basic level of transaction isolation is read committed. It makes two guarantees:
1. When reading from the database, you will only see data that has been committed (no dirty reads).
2. When writing to the database, you will only overwrite data that has been committed (no dirty writes).

### Snapshot Isolation and Repeatable Read
Snapshot isolation is the most common solution to this problem. The idea is that each transaction reads from a consistent snapshot of the database -- that is, the transaction sees all the data that was committed in the database at the start of the transaction sees all the data is subsequently changed by another transaction, each transaction sees only the old data from that particular point in time.
```ad-note
省略一部分副题
```
#### Repeatable read and naming confusion
```ad-abstract
Snapshot isolation is a useful isolation level, especially for read-only transactions. However, many databases that implement it call it by different names. In oracle it is called serializable, and in PostgreSQL and MySQL it called repeatable.

```
As a result, nobody really knows what repeatable read means.

### Preventing Lost Updates
```ad-tip
下面是具体的解决方案
```
#### Atomic write operations
Many databases provide atomic update operations, which remove the need to implement read-modify-write cycles in application code. They are usually the best solution if your code can be expressed in terms of those operations. For example, the following instructions is concurrency-safe in most relational database:
```sql
UPDATE counters SET value = value + 1 WHERE key = 'foo';
```
#### Explicit locking
Another option for preventing lost updates, if the database's built-in atomic operations don't provide the necessary functionality, is for the application to explicitly lock objects that are going to be updated. Then the application can perform a read-modify-write cycle, and if any other transaction tries to concurrently read the same object, it is forced to wait until the first read-modify-write cycle has completed.
```sql
BEGIN TRANSACTION;
SELECT * FROM figures
	WHERE name = 'robot' AND game_id = 222
	FOR UPDATE;
 -- Check whether move is valid, then update the position
 -- of the piece that was returned by the previous SELECT.
 UPDATE figures SET position = 'C4' WHERE id = 1234;
 COMMIT;
```
```ad-note
The `FOR UPDATE` clause indicates that the database should take a lock on all rows returned by this query.
```
#### Automatically detecting lost updates
Atomic operations and locks are ways of preventing lost updates by forcing the read-modify-write cycles to happen sequentially. An alternative is to allow them to execute in parallel and, if the transaction manager detects a lost update, abort the transaction and force it to retry its read-modify-write cycle.
```ad-important
PostSQL's repeatable read, Oracle's serializable, and SQL Server's snapshot isolation levels automatically detect when a lost update has occured and abort the offending transaction. However, MYSQL/InnoDB's repeatable read does not detect lost updates.
```

#### Compare-and-set
In databases that don't provide transactions, you sometimes find an atomic compare-and-set operation. The purpose of this operation is to avoid lost updates by allowing an update to happen only if the value has not changed since you last read it. If the current value does not match what you previously read, the update has no effect, and the read-modify-write cycle must be retried.
#### Conflict resolution and replication
In replicated databases, preventing lost updates takes on another dimension: since they have copies of the data on multiple nodes, and the data can potentially be modified concurrently on different nodes, some additional steps need to taken to prevent lost updates.

### Write Skew and Phantoms
#### Characterizing write skew
This anomaly is called write skew. It is neither a dirty write nor a lost update, because the two transactions are updating two different objects. It is less obvious that a conflict occurred here, but it's definitely a race condition: if the two transactions had run one after another, the second doctor would have been prevented from going off call. The anomalous behavior was only possible because the transactions ran concurrently.
#### Materializing conflicts
Materializing conflicts that take a phantom and turns it into a lock conflict on a concrete set of rows that exist in the database. 
```ad-tip
Materializing conflicts should be considered a last resort if no alternative is possible. A serializable isolation level is much preferable in most cases.
```
### Serializability
Most databases that provide serializability today use one of three techniques, which we will explore in the rest of this chapter:
- Literally executing transactions in a serial order
- Two-phase locking, which for several decades was the only viable option
- Optimistic concurrency control techniques such as serializable snapshot isolation

### Actual Serial Execution
The simplest way of avoiding concurrency problems is to remove the concurrency entirely.
#### Encapsulating transactions in stored procedures
#### Pros and cons of stored procedures
Stored procedures have existed for some time in relational databases, and they have been part of the SQL standard since 1999. They have gained a somewhat bad reputation, for various reasons:
- Each database vendor has its own language for stored procedures.
- Code running in a database id difficult to manage.
- A database is often much more performance-sensitive than an application server.
#### Partitioning

## Chapter 8. The Trouble with Distributed Systems
### Faults and Partial Failures
### Unreliable Networks
#### Timeouts and Unbounded Delays
Taking into account your application's characteristics, you can determine an appropriate trade-off between failure detection delay and risk of premature timeouts.
#### Synchronous Versus Asynchronous Networks
##### Can we not simply make network delays predictable?
```ad-faq
*Latency and Resource Utilization*
More generally, you can think of variable delays as a consequence of dynamic resource partirtioning.

Say you have a wire between two telephone switches that can carry up to 10,000 simultanous call. Each circuit that is switched over this wire occupies one of those call slots. Thus you can think of the wire as a resource that can be shared by up to 10,000 simultanous users. The resource is divided up in a static way: even if you're the only call on the wire right now, and all other 9,999 slots are unused, your circuit is still allocated the same fixed amount of bandwidth as when the wire is fully utilized.
```
Consequently, there's no "correct" value for timeouts -- they need to be determined experimentally.

### Unreliable Clocks
Clocks and time are important. Applications depend on clocks in various ways to answer questions like the following:
1. Has this request timed out yet?
2. What's the 99th percentile response time of this service?
3. How many queries per second did this service handle on average in the last five minutes?
4. How long did the user spend on our site?
5. When was this article published?
6. At what date and time should the reminder email be sent?
7. When does this cache entry expire?
8. What is the timestamp on this error message in the log file?

### Monotonic Versus Time-of-Day Clocks
#### Time-of-day clocks
A time-of-day clock does what you intuitively expect of a clock: it returns the current date and time according to some calendar (also known as wall-clock time).
```ad-note
In particular, if the local clock is too far ahead of the NTP server, it may be forcibly reset and apper to jump back to a prvious point in time. These jumps, as well as the fact that they often ignore leap seconds, make time-of-day clocks unsuitable for measuring elapsed time.
```

#### Monotonic clocks
A monotonic clock is suitable for measuring a duration (time interval), such as a timeout or a service's response time: `clock_gettime(CLOCK_MONOTONIC)` on Linux and `System.nanotime()` in Java are monotonic clocks, for example. The name comes from the fact that they are guaranteed to always move forward (whereas a time-of-day clock may jump back in time).

You can check the value of the monotonic clock at one point in time, do something, and then check the clock again at a later time.

### Relying on Synchronized Clocks
The problem with clocks is that while they seem simple and easy to use, they have a surprising number of pitfalls: a day may not have exactly 86400 seconds, time-of-day clocks may move backward in time, and the time on one node may be quite different from the time on another node.

Earlier in this chapter we discussed networks dropping and arbitrarily delaying packets. Even though networks are well behave most of the time, software must be designed on the assumption that the network will occasionally be faulty, and the software quite handle such faults gracefully. The same is true with clocks: although they work quite well most of the time, robust software needs to be prepared to deal with incorrect clocks.

### Timestamps for ordering events
Let's consider one particular situation in which it is tempting, but dangerous, to rely on clocks: ordering of events across multiple nodes. For example, if two clients write to a distributed database, who got there first? Which write is the more recent one?

So-called *logical clocks*, which are based on incrementing counters rather than an oscillating quartz crystal, are a safer alternative for ordering events (see "Detecting Concurrent Writes"). Logical clocks do not measure the time of day or the number of seconds elapsed, only the relative ordering of events (whether one event happened before or after another). In contrast, time-of-day and monotonic clocks, which measure actual elapsed time, are also known as physical clocks. We'll look at ordering a bit more in "[[Ordering Guarantees]]".
### Clock reading have a confidence interval

```ad-abstract
## Linearizability Versus Serializability
Linearizability is easily confused with Serializability (see [[Serializability]]), as both words seem to mean something like "can be arranged in a sequential order" However, they are two quite different guarantees, and it is important to distinguish between them:
Serializability:
	Serializability is an isolation property of transactions, where every transaction may read and write multiple objects (rows, documents, records) -- see "Single Object and Multi-Object Operations". It guarantees that transaction behave the same as if they had executed in some serial order (each transaction running to completion before the next transaction starts). It is okay for that serial order to be different from the order in which transactions were actually run.

Linearizability:
	Linearizability is a recency guarantee on reads and writes of a register (an individual object). It doesn't group operations together into transactions, so it does not prevent problems such as write skew (see [[Write Skew and Phantoms]]), unless you take additional measures such as materializing conflicts (see [[Materializing conflicts]]).

A database may provide both serializability and linearizability, and this combination is known as strict serializability or strong one-copy serializability (strong-1SR). Implementations of serializability based on two-phase locking (see [[Two-Phase Locking (2PL)]]) or actual serial execution (see [[Actual Serial Execution]]) are typically linearizable.

However, serializable snapshot isolation (see [[Serializable Snopshot Isolation]]) is not linearizable: by design, it makes reads from a consistent snapshot, to avoid lock contention between readers and writers. The whole point of a consistent snapshot is that it does not include writes that are more recent than the snapshot, and thus reads from the snapshot are not linearizable.

```

### Relying on Linearizability
#### Locking and leader election
#### Constrains and uniqueness guarantees
These constraints all require there to be a single up-to-date value (the account balance, the stock level, the seat occupancy) that all nodes agree on.

However, a hard uniqueness constraint, such as the one you typically find in relational databases, requires linearizability. Other kinds of constraints, such as foreign key or attribute constraints, can be implemented without requiring linearizability.
#### Cross-channel timing dependencies

#### Implementing Linearizability
Since linearizability essentially means "behave as though there is only a single copy of the data, and all operations on it are atomic," the simplest answer would be to really only use a single copy of the data. However, that approach would not be able to tolerate faults: if the node holding that one copy failed, the data would be lost, or at least inaccessible until the node was brought up again.

The most common approach to making a system fault-tolerant is to use replication. Let's revisit the replication methods from [[Chapter 5]], and compare whether they can be made linearizable:
*Single-leader replication (potentially linearizable)*
*Consensus algorithms (linearizable)*
*Multi-leader replication (not linearizable)*
*Leaderless replication (probably not linearizable)*

## Chapter 9.
### Linearizability
### Ordering Guarantees
We illustrated the ordering in Figure 9-4 by joining up the operations in the order in which they seem to have executed.
Ordering has been a recurring theme in this book, which suggests that it might be an important fundamental idea. Let's briefly recap some of the other contexts in which we have discussed ordering :
- In [[Chapter 5]] we saw that the main purpose of the leader in single-leader replication is to determine the order of writes in the replication log -- that is, the order in which followers apply those writes. If there is no single leader, conflicts can occur due to concurrent operations (see [[Handling Write Conflicts]]).
- Serializability
- The use of timestamps and clocks in distributed systems.

### Ordering and Causality
There are several reasons why ordering keeps coming up, and one of the reason is that it helps preserve causality.

Causality imposes an ordering on events: cause comes before effect;  a message is sent before that message is received; the question comes before the answer. 
If a system obeys the ordering imposed by causality, we say that it is causally consistent.

#### The causal order is not a total order
The difference between a total order and a partial order is reflected in different database consistency models:
Linearizability
	In a linearizable system, we have a total order of operations: if the system behaves as if there is only a single copy of the data, and every operation is atomic, this means that for any two operations we can always say which one happened first. 
Causality
	We said that two operations are concurrent if neither happened before the other (see "The "happens-before" relationship and concurrency"). Put another way, two events are ordered if they are causally related (one happened before the other), but they are incomparable if they are concurrent. This means that causality defines a partial order, not a total order: some operations are ordered with respect to each other, but some are incomparable.

#### Linearizability is stronger than causal consistency
- The fact that linearizability ensures causality is what makes linearizable systems simple to understand and appealing. 
- Making a system linearizable can harm its performance and availability.
- In fact, causal consistency is the strongest possible consistency model that does not slow down due to network delays, and remains available in the face of network failures.
-  Based on this observation, researchers are exploring new kinds of databases that preserve causality, with performance and availability characteristics that are similar to those of eventually consistency systems.
- It has yet made its way into production systems, and there are still challenges to be overcome.

#### Capturing causal dependencies
In order to maintain causality, you need to know which operation happened before which other operation. This is a partial order: concurrent operations may be processed in any order, but if one operation happened before another, then they must be processed in that order on every replica.

#### Sequence Number Ordering
Explicitly tracking all the data that has been read would mean a large overhead. So, there is a better way: we can use *sequence numbers or timestamps* to order events.
In a database with single-leader replication (see "Leaders and Followers"), the replication log defines a total order of write operations that is consistent with causality.
Various methods are used in practice:
- Each node can generate its own independent set of sequence numbers.(For example, if you have two nodes, one node can generate only odd numbers and the other only even numbers.)
- You can attach a timestamp from a time-of-day clock(physical clock) to each operation. (Such timestamps are not sequential)
- You can preallocate blocks of sequence numbers. (For example, node A might claim the block of sequence numbers from 1 to 1000, and node B might claim the block from 1,001 to 2,000).

#### Noncausal sequence number generators

#### Lamport timestamps
A Lamport timestamp bears no relationship to a physical time-of-day clock, but it provides total ordering: if you have two timestamps, the one with a greater counter value is the greater timestamp; if the counter values are the same, the one with the greater node ID is the greater timestamp.
The key idea about Lamport timestamps, which makes them consistent with causality, is the following: every node and every client keeps track of the maximum counter value it has seen so far, and includes that maximum on every request.
Lamport timestamps are sometimes confused with version vectors.
Although there are some similarities, they have a different purpose: version vectors can distinguish whether two operations are concurrent or whether one is causally dependent on the other, whereas Lamport timestamps always enforce a total ordering.
The advantage of Lamport timestamps over version vectors is that they are more compact.

#### Timestamp ordering is not sufficient

### Total Order Broadcast
```ad-abstract
#### Scope of ordering guarantee
Partitioned databases with a single leader per partition often miantain ordering only per partition, which means they cannot offer consistency guarantees (e.g., consistent snapshots, foreign key references) across all partitions is possible, but requires additional coordition.
```
Total order broadcast requires that two safety properties always be satisfied:
Reliable delivery
	No messages are lost: if a message is delivered to one node, it is delivered to all nodes.
Totally ordered delivery
	Messages are delivered to every node in the same order.

#### Using total order broadcast
