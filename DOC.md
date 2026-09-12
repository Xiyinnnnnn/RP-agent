# RP-agent

```text
ROOT = ~/RP-agent
DOC  = Agent-only architecture contract

THIS FILE:
  = architecture
  + authority
  + state transition
  + data contract
  + context model
  + generation model
  + cache model
  + failure model
  + invariants
  + exact mathematical definitions

CODE = implementation
DOC  = model boundary
```

## 0. SYSTEM MODEL

```text
PLAYER
  ↓
WORLD / GM
  ↓
REAL WORLD EXECUTION
  ↓
CANON
  ↓
PERSISTENT STATE
  ↓
MINIMAL STORY CONTEXT
  ↓
STORY WRITER
  ↓
STORY
  ↓
PLAYER
```

```text
agent.py    = World Runtime / GM / Canon
subagent.py = Character-local inference
story.py    = Stateless Story Writer
play.py     = IO
run         = only Model-facing Tool
filesystem  = persistent external state
cache       = ephemeral prediction data
```

```text
WORLD SIDE:
  what happened
  what is true
  what changed
  what persists

STORY SIDE:
  how to express confirmed information
  how to write the current scene

CHARACTER SIDE:
  what this character would think/say/do now
```

Architecture is a responsibility separation, not a shared-context architecture. The current repository defines `agent.py` as the World/GM side, `subagent.py` as local Character inference, and `story.py` as the separate Story writer. 

---

# 1. AUTHORITY MODEL

```text
USER REQUEST
  !=
WORLD FACT

CHARACTER RESULT
  !=
WORLD FACT

STORY
  !=
WORLD FACT

OPTIONS
  !=
WORLD FACT

MTP CANDIDATE
  !=
WORLD FACT
```

唯一合法的 Canon 形成链：

```text
REAL EXECUTION RESULT
        +
     GM CONFIRM
        ↓
      CANON
        ↓
     STATE
```

定义：

```text
E_t = real execution result at time t
G_t = GM confirmation at time t
C_t = Canon at time t
S_t = persistent State at time t

C_t = Confirm(E_t, G_t)

S_t+1 =
    Merge(S_t, C_t)
    if C_t contains confirmed durable change
    else S_t
```

因此：

```text
Story -> State     INVALID
Story -> Canon     INVALID
Character -> State INVALID
Options -> State   INVALID
MTP -> State       INVALID
Beat -> Event      INVALID
```

---

# 2. WORLD STATE MODEL

```text
S_t = persistent world state
H_t = continuity history
M_t = compressed historical summary
I_t = current player input
A_t = executed world action
R_t = observed real result
```

世界状态转移：

```text
S_t
 + I_t
 + necessary retrieved data
 + A_t
 + R_t
        ↓
      GM
        ↓
      C_t
        ↓
S_t+1
```

严格定义：

```text
S_{t+1} = T(S_t, I_t, A_t, R_t, C_t)
```

其中：

```text
T(...) = S_t
    when no confirmed durable change exists

T(...) != S_t
    only when GM confirms a durable world change
```

State 写入条件：

```text
WRITE_STATE(t)
⇔
confirmed(t)
∧ durable(t)
```

所以：

```text
temporary scene      -> no State
draft                 -> no State
story prose           -> no State
speculation           -> no State
option                -> no State
unconfirmed result    -> no State
MTP candidate         -> no State

confirmed durable fact
                      -> State
```

---

# 3. HISTORY / SUMMARY MODEL

```text
State   = durable truth
History = continuity record
Summary = compressed History
```

关系：

```text
State_t
  !=
History_t

History_t
  !=
Summary_t
```

Summary 不拥有独立 Canon authority：

```text
Authority(State)
  >
Authority(History)
  >
Authority(Summary)
```

Summary 是压缩函数：

```text
M_t = Compress(H_{≤t})
```

不是：

```text
M_t = Canon
```

---

# 4. CHARACTER MODEL

Character Agent 接口：

```text
C_in =
    CharacterCard
  + LocalContext
  + OptionalDynamicState

C_out =
    LocalCharacterResult
```

函数：

```text
C_out = CharacterModel(C_in)
```

Character Result 的语义域：

```text
thought
speech
emotion
reaction
local action
```

不是：

```text
world fact
canon
state diff
global consequence
```

合法链：

```text
Character Card
      +
Local Context
      ↓
Character Agent
      ↓
Character Result
      ↓
GM
      ↓
Canon decision
```

因此：

```text
CharacterResult -> State
```

不是直接合法映射。

正式表示：

```text
StateCommit(CharacterResult)
```

必须经过：

```text
GMConfirm(...)
```

即：

```text
StateCommit =
    Commit(
        GMConfirm(
            CharacterResult
        )
    )
```

---

# 5. TOOL MODEL

```text
run = only Model-facing Tool
```

外部行动闭环：

```text
reason
  ↓
run
  ↓
real result
  ↓
inspect
  ↓
reason
```

定义：

```text
O_t = observation returned by real execution

Model must use:
  O_t

Model must not use:
  "assumed O_t"
```

禁止：

```text
not executed -> assume success
not observed -> assume file exists
failed API -> assume generated
failed tool -> treat as world result
```

真实结果函数：

```text
O_t = Execute(A_t)
```

不是：

```text
O_t = Infer(A_t)
```

---

# 6. RETRIEVAL MODEL

目录不是知识本身。

```text
目录.md = navigation index
target file = actual data
```

检索：

```text
Index
  ↓
Locate
  ↓
Read target
```

不是：

```text
Directory
  ↓
scan all files
  ↓
inject all content
```

定义资源全集：

```text
R = {r_1, r_2, ..., r_n}
```

当前任务需要的信息集合：

```text
N_t ⊆ R
```

实际暴露集合：

```text
X_t ⊆ R
```

硬约束：

```text
N_t ⊆ X_t
```

优化目标：

```text
min |X_t|
subject to
N_t ⊆ X_t
```

这就是：

```text
按需暴露
=
最小充分信息集
```

不是：

```text
越少越好
```

而是：

```text
无必要 -> 不读
必要   -> 必须读
```

---

# 7. CONTEXT MODEL

定义 World-side working context：

```text
W_t =
    CurrentInput
  + RelevantState
  + NecessaryHistory
  + NecessarySummary
  + RelevantCharacter
  + RelevantWorldBook
  + CharacterResults
```

定义 Story Context：

```text
K_t =
    minimal_sufficient(
        current_input,
        confirmed_state,
        confirmed_changes,
        necessary_history,
        necessary_summary,
        relevant_characters,
        relevant_worldbook,
        character_results,
        story_task
    )
```

关键性质：

```text
K_t != complete world
K_t != full history
K_t != world database
K_t != agent memory dump
K_t != persistent state
```

而：

```text
K_t = current writing interface
```

---

# 8. CONTEXT SUFFICIENCY

设：

```text
D_t = all data actually required for the current story task
K_t = exposed Story Context
```

定义遗漏损失：

```text
L_missing(K_t)
```

定义无关噪声：

```text
L_noise(K_t)
```

定义上下文成本：

```text
Cost(K_t)
```

Context 目标：

```text
minimize:

J(K_t)
=
α * L_missing(K_t)
+
β * L_noise(K_t)
+
γ * Cost(K_t)
```

其中：

```text
α > 0
β > 0
γ > 0
```

并且：

```text
L_missing = 0
```

是可接受写作上下文的必要条件。

因此最优 Context 不是：

```text
maximum context
```

而是：

```text
minimal sufficient context
```

---

# 9. INFORMATION VALUE MODEL

对任意候选数据项 `x`：

```text
x ∈ CandidateContext
```

定义其边际价值：

```text
V(x | K)
=
Q(K ∪ {x})
-
Q(K)
```

其中 `Q` 是当前任务写作质量函数。

若：

```text
V(x | K) ≤ 0
```

且 `x` 非必要事实，则：

```text
x 不应默认暴露
```

若：

```text
x ∈ D_t
```

则即使成本较高，也不能因为 token 成本直接删除。

因此：

```text
necessary data
  > token saving

irrelevant data
  < clean context
```

---

# 10. WRITER MODEL

Story Writer 输入：

```text
A = WritingAsset
K_t = current Story Context
```

输出：

```text
Y_t = Story
```

精确定义：

```text
Y_t = Fθ(A, K_t)
```

其中：

```text
θ = model parameters
A = stable writing system
K_t = local user-side reference data
```

系统侧：

```text
SYSTEM = WritingAsset
```

用户侧：

```text
USER = local reference data
```

因此：

```text
system != world memory
user   != hidden controller
```

---

# 11. ONE-SHOT WRITING MODEL

每轮默认：

```text
A_t
  +
K_t
  ↓
1 × Fθ
  ↓
Y_t
```

即：

```text
Y_t = Fθ(A_t, K_t)
```

生成后：

```text
discard writer working context
```

跨轮持久化只发生在 World side：

```text
Persistent:
  State
  History
  Summary

Ephemeral:
  Story Context
  Writer working context
```

因此：

```text
Persistence(World)
+
StatelessWriting(Story)
```

而不是：

```text
PersistentWriterMemory
```

---

# 12. RESPONSIBILITY SEPARATION

定义三个函数：

```text
W_t = WorldModel(...)
C_t = CharacterModel(...)
Y_t = StoryModel(...)
```

世界函数：

```text
W_t:
  decide facts
  execute actions
  update state
  construct Story Context
```

角色函数：

```text
C_t:
  infer local character behavior
```

写作函数：

```text
Y_t:
  express supplied facts
```

禁止交换：

```text
Y_t -> Canon
C_t -> Canon
```

除非显式经过：

```text
GMConfirm(...)
```

因此系统不是：

```text
three agents sharing one mind
```

而是：

```text
three functions
connected by
typed interfaces
```

---

# 13. STORY INTERFACE AS TYPE SYSTEM

把 Story Context 看成类型：

```text
StoryContext : Data
```

Writer 接受：

```text
StoryModel : WritingAsset × StoryContext -> Story
```

Writer 不接受：

```text
Writer : WorldState -> WorldMutation
```

不存在合法类型：

```text
Story -> State
Story -> Canon
Story -> History
```

因此：

```text
Writer output type = Story
```

不是：

```text
WorldMutation
```

这就是写作越权的形式化定义。

---

# 14. STORY FACT CONSERVATION

设：

```text
Facts(K_t) = facts explicitly supplied to Writer
Facts(Y_t) = facts asserted by Story
```

定义 Writer 新增世界事实：

```text
NovelFact(Y_t, K_t)
=
Facts(Y_t) \ Facts(K_t)
```

理想约束：

```text
NovelFact(Y_t, K_t)
```

不得升级为 Canon。

即：

```text
NovelFact
  !=
Canon
```

Writer 可以进行：

```text
expression
description
ordering
pacing
dialogue
sensory realization
narrative inference
```

但：

```text
narrative inference
!=
world authority
```

---

# 15. DATA QUALITY MODEL

设输入数据质量为：

```text
Q_data
```

写作资产质量为：

```text
Q_asset
```

模型先验与采样条件为：

```text
Q_model
```

最终质量：

```text
Q_story
=
F(Q_asset, Q_data, Q_model)
```

因此：

```text
Q_data ↓
=> Q_story ceiling ↓
```

但：

```text
|K| ↑
```

不保证：

```text
Q_story ↑
```

因为加入的数据可以分为：

```text
relevant
irrelevant
conflicting
redundant
missing
```

其影响：

```text
relevant      -> positive potential
irrelevant    -> noise
conflicting   -> instability
redundant     -> cost
missing       -> under-specification
```

---

# 16. CONTEXT NOISE MODEL

定义：

```text
K_t = D_t ∪ N_t
```

其中：

```text
D_t = necessary data
N_t = unnecessary data
```

总负担：

```text
B_t
=
B_need(D_t)
+
B_noise(N_t)
```

目标：

```text
min B_noise(N_t)
subject to
D_t ⊆ K_t
```

所以：

```text
更多 Context
```

不是默认优化方向。

真正目标：

```text
更多有效信息
+
更少无关信息
```

---

# 17. PROMPT MODEL

三个 Agent 的 system：

```text
GM:
  NSFW_LAYER + GM_RUNTIME

STORY:
  NSFW_LAYER + STORY_RUNTIME + HAGENT_ASSETS

CHARACTER:
  NSFW_LAYER + CHARACTER_PROMPT + RoleCard
```

Writer 资产：

```text
A =
    CORE
  + FLOW
  + STYLE
  + REFERENCE
  + CHECK
```

资产是：

```text
stable control prior
```

不是：

```text
world state
```

---

# 18. PROMPT QUALITY MODEL

设：

```text
Q_p = writing quality
```

Prompt engineering 的作用可表示为：

```text
Q_p(new)
=
Q_p(base)
+
Δ_left_tail
+
Δ_median
+
ε
```

当前实验结论：

```text
Δ_left_tail > 0
Δ_median   > 0
```

但存在：

```text
lim_{additional_prompt_complexity → large}
    ΔQ_p
```

趋于平台。

因此：

```text
Prompt Engineering
  = 有效
  != 无限有效
```

已验证正确方向：

```text
优化左尾
抬高整体中位水平
降低方差
```

而非：

```text
无限增加规则
无限增加层次
无限增加控制词
```

---

# 19. CONTEXT ENGINEERING MODEL

定义长上下文系统：

```text
Y_long = Fθ(A, K_large)
```

定义干净局部上下文：

```text
Y_local = Fθ(A, K_min)
```

在项目当前实验中：

```text
128 × A/B
```

得到：

```text
Context Engineering
  -> no practical positive gain
  -> long-form AI-like style worsened
```

因此当前默认：

```text
K_min > K_large
```

这里的 `>` 不是 token 数量比较，而是：

```text
作为默认写作策略的优先级
```

即：

```text
clean local context
  >
long accumulated context
```

---

# 20. ARCHITECTURE OBJECTIVE

整个系统优化目标不是：

```text
maximize information
```

而是：

```text
maximize useful information
while minimizing responsibility leakage
and unnecessary context
```

形式化：

```text
maximize:

U
=
Q_story
-
λ1 * ContextNoise
-
λ2 * AuthorityLeak
-
λ3 * UnnecessaryState
-
λ4 * ArchitectureComplexity
```

约束：

```text
AuthorityLeak = 0
State corruption = 0
Canon ambiguity = 0
```

---

# 21. WORLD / STORY DECOUPLING

定义：

```text
World State:
  S_t

Story Context:
  K_t

Story:
  Y_t
```

关系：

```text
S_t
 ↓
GM
 ↓
K_t
 ↓
Story
 ↓
Y_t
```

没有：

```text
Y_t -> S_t
```

所以：

```text
S_t = persistent
K_t = ephemeral
Y_t = disposable
```

这构成系统最核心的三元模型：

```text
PERSISTENT WORLD
      ↓
EPHEMERAL INTERFACE
      ↓
STATELESS WRITER
```

---

# 22. STORY CONTEXT AS INFORMATION BOTTLENECK

接口不是越宽越好。

定义：

```text
I_world
=
information available to GM

I_story
=
information exposed to Writer
```

要求：

```text
I_story ⊂ I_world
```

并且：

```text
I_story ⊇ I_required
```

所以：

```text
I_required ⊆ I_story ⊂ I_world
```

这正是：

```text
窄接口
```

而不是：

```text
world dump
```

---

# 23. INFORMATION FLOW CONSERVATION

合法数据流：

```text
Player
  ↓
GM
  ↓
World execution
  ↓
Observed result
  ↓
Canon
  ↓
State
  ↓
Story Context
  ↓
Story
```

任何跳过 GM Canon 的世界写入：

```text
INVALID
```

任何跳过 World State / confirmed data 的假定世界事实：

```text
INVALID
```

任何从 Story output 自动反向提交 World State：

```text
INVALID
```

---

# 24. STORY BEAT MODEL

定义：

```text
F_t = world fact
A_t = action
R_t = consequence
B_t = narrative beat
Y_t = prose
```

合法方向：

```text
F_t
 →
A_t
 →
R_t
 →
B_t
 →
Y_t
```

不允许：

```text
Y_t -> F_t
Y_t -> R_t
B_t -> R_t
B_t -> Canon
```

形式化：

```text
B_t = Present(R_t)
```

不是：

```text
R_t = Generate(B_t)
```

因此：

```text
Beat = representation
not authority
```

---

# 25. OPTIONS MODEL

Options 是：

```text
O_t = optional action suggestions
```

定义：

```text
O_t ⊂ PossibleActions(S_t)
```

但：

```text
SelectedAction_t ∉ O_t
```

直到玩家实际选择。

所以：

```text
Option != Action
Option != Canon
Option != State
```

玩家自由输入：

```text
I_t ∈ AllPlayerInputs
```

而不是：

```text
I_t ∈ O_t
```

---

# 26. MTP MODEL

MTP 不改变 World Model。

```text
OWNER = agent.py
WRITER = ordinary story.py
DEFAULT = OFF
```

候选：

```text
Y'_t = StoryModel(A, K'_t)
```

候选只是：

```text
prediction cache
```

定义：

```text
FP(S_t) = StateFingerprint(S_t)
```

候选有效条件：

```text
Valid(candidate, t)
⇔
same_RP
∧ same_StateFingerprint
∧ matching_condition
∧ cache_integrity
```

即：

```text
Valid_t =
R_t_same
∧ FP_t_same
∧ Match_t
∧ Integrity_t
```

若：

```text
Valid_t = false
```

则：

```text
candidate discarded
ordinary generation
```

不允许：

```text
uncertain -> reuse
```

---

# 27. MTP FAILURE MODEL

主链：

```text
MAIN = ordinary RP chain
```

MTP：

```text
SIDE = optional optimization
```

要求：

```text
Failure(MTP)
  -> MAIN unchanged
```

即：

```text
MTP failure probability
```

不得转化为：

```text
Main loop failure
```

数学上：

```text
P(MainFailure | MTPFailure)
```

应尽可能等于：

```text
P(MainFailure | MTPDisabled)
```

架构目标：

```text
MTP = orthogonal optimization
```

而非：

```text
MTP = dependency
```

---

# 28. CACHE MODEL

缓存状态：

```text
CacheEntry =
(
    rp_id,
    state_fingerprint,
    condition,
    story,
    integrity
)
```

读取：

```text
lookup(
    rp_id,
    state_fingerprint,
    current_condition
)
```

任何以下变化：

```text
RP
State
key condition
candidate integrity
```

都会使候选失效。

定义：

```text
CacheHit
=
KeyMatch
∧ StateMatch
∧ ConditionMatch
∧ IntegrityOK
```

否则：

```text
CacheMiss
```

---

# 29. FILESYSTEM MODEL

```text
~/RP-agent/
├── agent.py
├── story.py
├── subagent.py
├── play.py
├── launch.sh
├── install.sh
├── character/
├── worldbook/
└── rp/
    └── <RP>/
        ├── State.md
        ├── History.md
        └── Summary.md
```

语义：

```text
character/*.md
  = static character definition

worldbook/*.md
  = static world resource

State.md
  = confirmed durable facts

History.md
  = continuity

Summary.md
  = compressed history

~/.cache/rp-agent/
  = ephemeral data
```

当前实现明确以 filesystem 作为运行环境，不使用 DB/RAG/Vector 数据层。 

---

# 30. TWO-WINDOW MODEL

```text
WINDOW 1
  = agent.py
  = state holder
  = GM control

WINDOW 2
  = play.py --attach
  = display + input forwarding
  = no world authority
```

状态唯一写者：

```text
writer(State) = agent.py
```

要求：

```text
|StateWriters| = 1
```

因此：

```text
State race
↓
structurally minimized
```

---

# 31. SESSION MODEL

定义：

```text
Session_t =
(
    active_rp,
    runtime_memory,
    current_task,
    current_context
)
```

注意：

```text
session memory != persistent State
```

即：

```text
Process memory
  !=
RP persistence
```

恢复 RP 时：

```text
filesystem
  ->
State
  ->
necessary History/Summary
  ->
new runtime session
```

不是：

```text
old Writer memory
```

---

# 32. FAILURE MODEL

所有失败必须保持失败真实性。

```text
ToolFailure
  -> no fabricated result

APIFailure
  -> no fabricated output

StoryFailure
  -> no fake Story success

CacheFailure
  -> ordinary generation

MTPFailure
  -> main chain continues

PersistenceFailure
  -> do not advance persisted truth
```

定义：

```text
FAILURE = observable failure
SUCCESS = observable success
```

禁止：

```text
unknown -> success
```

---

# 33. FALLBACK PARTIAL ORDER

优先级：

```text
REAL RESULT
  >
CONFIRMED STATE
  >
RELEVANT HISTORY
  >
SUMMARY
  >
INFERENCE
```

在 Story side：

```text
CONFIRMED CURRENT FACT
  >
RELEVANT CHARACTER FACT
  >
CURRENT TASK
  >
WRITING ASSET
  >
DECORATION
```

不允许低等级信息覆盖高等级事实：

```text
Inference
  X
Confirmed State
```

```text
Story wording
  X
Canon
```

---

# 34. CONSISTENCY MODEL

定义世界一致性：

```text
Consistent(S_t, H_t, M_t)
```

至少满足：

```text
State facts
  ⊆
facts compatible with confirmed History
```

并且：

```text
Summary
```

只能压缩：

```text
History
```

不能创造新的 Canon。

Story Context 必须满足：

```text
Consistent(K_t, S_t, C_t)
```

即：

```text
Story Context
  cannot contradict
confirmed world truth
```

---

# 35. TRANSACTION MODEL

一轮世界操作可视为事务：

```text
BEGIN
  ↓
READ
  ↓
ACT
  ↓
OBSERVE
  ↓
CONFIRM
  ↓
COMMIT
```

失败：

```text
ROLLBACK / NO COMMIT
```

尤其：

```text
Story generated
+
State write failed
```

不能推出：

```text
State successfully persisted
```

反之：

```text
State commit
```

也不能自动推出：

```text
Story generation success
```

两者是两个不同阶段。

---

# 36. ATOMIC RESPONSIBILITY

定义：

```text
World transaction
  = world truth transaction

Story generation
  = expression transaction
```

两者不合并。

```text
World transaction:
  fact-oriented

Story transaction:
  expression-oriented
```

所以：

```text
World success
!=
Story success

Story success
!=
World commit
```

---

# 37. MODEL ATTENTION

模型注意力不是无限资源。

设：

```text
A_total
```

为可分配注意资源。

划分：

```text
A_total
=
A_world
+
A_character
+
A_story
+
A_noise
```

目标：

```text
min A_noise
```

World Agent：

```text
maximize A_world
```

Character Agent：

```text
maximize A_character
```

Story Agent：

```text
maximize A_story
```

所以：

```text
Cross-role context
```

若不能提高当前任务信息价值，则属于：

```text
attention leakage
```

---

# 38. ATTENTION LEAKAGE MODEL

定义：

```text
Leak =
attention spent on information
outside current responsibility
```

目标：

```text
min Leak
```

典型泄漏：

```text
Story Agent reading full RP
Story Agent managing Canon
Character Agent reasoning global world
GM Agent carrying unnecessary prose-writing history
```

因此：

```text
职责隔离
=
注意力隔离
```

---

# 39. CLEAN CONTEXT PRINCIPLE

本项目默认：

```text
clean context
>
long context

local context
>
global context

necessary data
>
available data

confirmed data
>
inferred data

one-shot writing
>
writer memory
```

注意：

```text
clean != empty
local != insufficient
short != incomplete
```

准确目标：

```text
minimal + sufficient + relevant + consistent
```

---

# 40. DATA → OUTPUT MODEL

最终 Story：

```text
Y_t
=
Fθ(
    A_t,
    K_t
)
```

其中：

```text
A_t = writing control
K_t = reference data
θ   = model prior
```

因此：

```text
A_t
```

控制：

```text
how to write
```

而：

```text
K_t
```

决定：

```text
what can safely be written
```

所以：

```text
system controls expression
user data constrains content
```

二者职责不同。

---

# 41. DATA CEILING

定义：

```text
Ceiling(K_t)
```

为当前输入允许的合理表达空间。

若：

```text
K_t
```

缺少关键事实：

```text
Ceiling ↓
```

若：

```text
K_t
```

增加大量无关数据：

```text
Noise ↑
```

因此：

```text
Quality
≈
usable information
rather than raw information
```

---

# 42. WRITING AS CONDITIONAL GENERATION

Story generation 本质：

```text
P(Y | A, K)
```

不是：

```text
P(Y | entire world)
```

也不是：

```text
P(Y | persistent writer memory)
```

所以每轮：

```text
Y_t ~ P(
    Y |
    A_t,
    K_t
)
```

这里：

```text
K_t
```

是当前局部条件。

---

# 43. WORLD AS STATEFUL PROCESS

世界运行：

```text
S_{t+1}
=
T(
    S_t,
    I_t,
    A_t,
    R_t,
    C_t
)
```

Story：

```text
Y_t
=
F(
    A_t^{write},
    K_t
)
```

二者函数不同：

```text
T != F
```

因此：

```text
World runtime
and
Story runtime
```

不应合并成一个职责函数。

---

# 44. INTERFACE MINIMALITY THEOREM

若：

```text
K_1 ⊂ K_2
```

且：

```text
K_2 \ K_1
```

不包含当前任务必要信息，则：

```text
K_1
```

优先于：

```text
K_2
```

因为：

```text
information sufficiency
already satisfied
```

而：

```text
additional information
```

只增加：

```text
cost
noise
competition
```

因此：

```text
Once sufficient,
more context has no architectural privilege.
```

---

# 45. NO FULL-CONTEXT FALLBACK

Writer 失败或表现不足时：

```text
FIRST RESPONSE
=
repair Story Context
```

不是：

```text
dump entire RP
```

决策：

```text
quality ↓
  ↓
inspect K_t
  ↓
find missing necessary information
  ↓
add only missing information
```

禁止默认：

```text
quality ↓
  ↓
full RP injection
```

---

# 46. PROMPT ASSET INTEGRITY

HAGENT_ASSETS：

```text
A = intact asset block
```

完整性：

```text
Hash(A) = expected_hash
```

若：

```text
Hash(A) != expected_hash
```

则：

```text
asset invalid
```

资产改变：

```text
must verify again
```

资产内容本身：

```text
do not silently summarize
do not silently split
do not silently normalize
do not silently reorder
```

当前代码将 H-agent 叙事资产作为 Story-side 固定资产，并保留单一 SHA256 校验。 ([GitHub][1])

---

# 47. CHANGE MODEL

修改任何功能前：

```text
identify responsibility
      ↓
identify contract
      ↓
identify invariant
      ↓
change smallest existing module
```

优先级：

```text
preserve architecture
>
preserve contract
>
preserve behavior
>
optimize implementation
```

禁止因为局部问题直接增加：

```text
Manager
Orchestrator
Plot Engine
State Engine
Beat Engine
new Loop
new business layer
```

---

# 48. ARCHITECTURE COMPLEXITY

定义：

```text
C_arch = number / weight of independent control mechanisms
```

目标：

```text
min C_arch
```

subject to:

```text
required behavior = preserved
```

因此：

```text
复杂性增加
```

必须证明：

```text
ΔQuality > 0
```

且：

```text
ΔFailure ≤ 0
```

否则：

```text
reject change
```

---

# 49. EXPERIMENTAL DECISION MODEL

对任何新机制 `m`：

```text
ΔQ = Q_with(m) - Q_without(m)
ΔF = Failure_with(m) - Failure_without(m)
ΔC = Cost_with(m) - Cost_without(m)
```

默认接受条件：

```text
ΔQ > 0
∧
ΔF ≤ 0
```

若：

```text
ΔQ ≈ 0
```

而：

```text
ΔC > 0
```

则：

```text
reject m
```

若：

```text
ΔQ < 0
```

则：

```text
reject m
```

---

# 50. PROMPT / CONTEXT TRADEOFF

定义总优化目标：

```text
J
=
Q
-
λC
-
μN
-
νL
```

其中：

```text
Q = writing quality
C = context cost
N = context noise
L = architecture leakage
```

要求：

```text
λ, μ, ν > 0
```

因此：

```text
quality gain
```

必须抵消：

```text
cost
+
noise
+
leakage
```

才能构成真实优化。

---

# 51. MODEL-ONLY PRIORITY

模型读取优先级：

```text
1. HARD INVARIANTS
2. AUTHORITY
3. CURRENT STATE
4. CURRENT TASK
5. DATA CONTRACT
6. CONTEXT RULE
7. FAILURE FALLBACK
8. IMPLEMENTATION DETAIL
```

不要用实现细节覆盖架构不变量。

---

# 52. HARD INVARIANTS

```text
I1   agent.py = Canon authority

I2   story.py = stateless writer

I3   subagent.py = local character inference

I4   play.py = IO

I5   run = only Model-facing Tool

I6   State = confirmed + durable facts only

I7   History = continuity

I8   Summary != Canon

I9   Character Result != Canon

I10  Story != Canon

I11  Options != Canon

I12  MTP Candidate != Canon

I13  Story never writes State

I14  Character never directly writes State

I15  Story Context is ephemeral

I16  Story Context is rebuilt per round

I17  Context is minimal + sufficient

I18  Writer does not search full world state

I19  Writer does not own long-term memory

I20  Writer does not decide world truth

I21  Tool result must be real

I22  failures are never fabricated as success

I23  MTP failure never breaks main chain

I24  cache mismatch => ordinary generation

I25  no unnecessary global context

I26  no new architecture without demonstrated need
```

---

# 53. COMPLETE FORMAL MODEL

整个项目可压缩为：

```text
World:

S_{t+1}
=
T(
    S_t,
    I_t,
    A_t,
    R_t,
    C_t
)

Character:

Z_t
=
CharacterModel(
    Card_t,
    LocalContext_t,
    DynamicState_t
)

Story Context:

K_t
=
MinimalSufficient(
    I_t,
    S_t,
    ΔS_t,
    H_t,
    M_t,
    Character_t,
    WorldBook_t,
    Z_t,
    Task_t
)

Story:

Y_t
=
StoryModel(
    A_write,
    K_t
)

Options:

O_t
=
OptionalSuggestions(
    S_t,
    I_t
)

MTP:

Y'_t
=
StoryModel(
    A_write,
    K'_t
)

Reuse:

Reuse_t
⇔
SameRP
∧ SameStateFingerprint
∧ MatchCondition
∧ IntegrityOK
```

---

# 54. GLOBAL CONSTRAINT SYSTEM

```text
World correctness:
    Canon must come from confirmed world result

State correctness:
    State stores durable confirmed truth only

Context correctness:
    Context is minimal sufficient

Writer correctness:
    Writer expresses supplied data only

Character correctness:
    Character gives local result only

Cache correctness:
    Cache never becomes truth

Failure correctness:
    failure never becomes success

Architecture correctness:
    responsibility boundaries remain stable
```

---

# 55. FINAL MODEL

```text
                    ┌──────────────┐
                    │    PLAYER    │
                    └──────┬───────┘
                           ↓
                    ┌──────────────┐
                    │  WORLD / GM  │
                    │   agent.py   │
                    └──────┬───────┘
                           │
             ┌─────────────┼─────────────┐
             ↓             ↓             ↓
          State         Character       Tools
             │           Agent            │
             │             ↓              │
             │       CharacterResult      │
             │             │              │
             └─────────────┼──────────────┘
                           ↓
                         Canon
                           ↓
                 minimal Story Context
                           ↓
                    ┌──────────────┐
                    │ STORY WRITER │
                    │   story.py   │
                    └──────┬───────┘
                           │
                      one-shot
                           ↓
                         Story
                           ↓
                        PLAYER
```

```text
THE CORE:

World State is persistent.
Story Context is ephemeral.
Story generation is stateless.

system = writing asset
user   = local reference data

GM decides:
    what happened

Character decides:
    local character behavior

Story decides:
    how to write it

No role crosses its authority boundary.
```

```text
OPTIMIZATION TARGET:

not:
    more context
    more memory
    more managers
    more loops
    more prompt rules

but:
    better prompt assets
    better local data
    smaller sufficient context
    stricter authority
    simpler architecture
    one clean writer run
```

[1]: https://github.com/Xiyinnnnnn/RP-agent/blob/main/DOC.md "RP-agent/DOC.md at main · Xiyinnnnnn/RP-agent · GitHub"
