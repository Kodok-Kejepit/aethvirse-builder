class_name JobTrial
extends RefCounted
## Job Change trial (§8): picking a job in the Codex sends you into a trial Gate; beating its
## boss grants the job. Hidden jobs skip it (their sealed mission was the trial).

const TRIAL_GATES: Array[String] = ["", "res://data/gates/trial_tier_1.tres", "res://data/gates/trial_tier_2.tres"]


static func needs_trial(job: JobData) -> bool:
	return not job.hidden and job.tier >= 1 and job.tier < TRIAL_GATES.size()


static func gate_for(job: JobData) -> GateData:
	return load(TRIAL_GATES[clampi(job.tier, 1, TRIAL_GATES.size() - 1)]) as GateData


## Enters the trial Gate for `job`. Returns false when not possible right now.
static func start(tree: SceneTree, player: Player, job: JobData) -> bool:
	if GameState.gate_session != null or player == null or not needs_trial(job):
		return false
	var session: GateSession = GateSession.new()
	session.gate = gate_for(job)
	session.trial_job = job.id
	session.return_scene = tree.current_scene.scene_file_path
	session.return_position = player.global_position
	GameState.gate_session = session
	SaveManager.autosave()
	tree.paused = false
	tree.change_scene_to_file.call_deferred(GatePortal.DUNGEON_SCENE)
	return true


## Called when the trial boss falls.
static func complete(job_id: StringName) -> bool:
	var player: Player = GameState.player as Player
	if player == null or not player.stats.change_job(job_id):
		return false
	var job: JobData = JobRegistry.get_job(job_id)
	Codex.notify(TranslationServer.translate(&"JOB_TRIAL_PASSED") % (job.display_name if job != null else String(job_id)), &"reward")
	AudioManager.play_ui(&"level_up")
	return true
