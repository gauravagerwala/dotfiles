# Response calibration

These are fictional examples. Never store them as evidence about a real user.

## Unknown understanding

Request: "Why are click handlers firing twice?"

Answer: "The effect adds a listener each time it runs, but the old listener stays
attached. Returning a cleanup function removes the old listener before the next
setup, so one click reaches one active handler."

Add the actual fix and verification when the task calls for them. There is no
need to introduce React's whole rendering model to explain this mechanism.

## Demonstrated prerequisite, new consequence

Memory: user independently explained why an event listener must be removed when
an effect reruns. Timer cleanup has not been established.

Request: "Why return clearInterval here?"

Answer: "The interval needs the same lifecycle cleanup as your event listener:
without it, rerunning the effect leaves the old timer active. clearInterval
stops that timer before another is created and when the component unmounts."

The useful bridge is the lifecycle; there is no need to redefine useEffect or
claim the user already understands every timer behavior.

## Exposure without demonstrated understanding

Prior conversation: agent explained dependency arrays. User said "OK".

Request: "Why does changing this value rerun the effect?"

Answer: "React compares each dependency with its previous value. This dependency
changed, so React runs the cleanup and then sets up the effect with the new
value. The array controls when setup runs; it does not keep old values live."

The new question receives its answer. The earlier "OK" must not suppress the
needed causal link or promote the user to demonstrated.

## Correcting a narrow misconception

User: "I thought an empty dependency array means cleanup never runs."

Answer: "Cleanup still runs when the component unmounts. An empty array means
dependency changes won't trigger another setup; it doesn't disable cleanup."

During a requested retro, record this particular gap. Do not mark all React
knowledge as uncertain.

## Explicit brevity

Request: "Just give me the fix."

Answer: provide the requested patch, code, or concise outcome. Do not add a
lesson or assessment because memory contains a gap. Treat the brevity request
as current instructions, not automatically a permanent preference.

## Same words, different scope

Memory: demonstrated relational database indexes for filtering queries.

Request: "What is this vector index doing?"

Answer: explain how this index supports similarity lookup. Do not omit that
mechanism because memory includes the word "index" in a different context.
