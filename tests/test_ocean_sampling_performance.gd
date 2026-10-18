extends SceneTree
class CountedOcean extends "res://presentation/toon_ocean.gd":
	var displacements := 0
	var noise_samples := 0
	func displacement(g: Vector2) -> Vector3:
		displacements+=1
		return super.displacement(g)
	func _wave_noise(g: Vector2,index: int) -> float:
		noise_samples+=1
		return super._wave_noise(g,index)
var failures := 0
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
## Frozen pre-optimization algorithm, independent of the optimized displacement.
func legacy_displacement(ocean, g: Vector2) -> Vector3:
	var d:=Vector3.ZERO
	for i in range(ocean._waves.size()):
		var wave: Dictionary=ocean._waves[i]
		var noise: Dictionary=ocean.settings.wave_noise
		var perturbation: float=ocean._wave_noise(g,i) if noise.enabled else 0.0
		var amplitude:=1.0+float(noise.amplitude_strength)*perturbation
		var theta: float=wave.k*wave.dir.dot(g)-wave.omega*ocean.time+wave.phase+float(noise.phase_strength)*perturbation
		var horizontal: Vector2=wave.dir*(wave.s/wave.k)*cos(theta)*amplitude
		d.x+=horizontal.x; d.z+=horizontal.y; d.y+=wave.a*sin(theta)*amplitude
	return d*ocean.fade_at(g)
func legacy_height(ocean, point: Vector2) -> float:
	var g:=point
	for i in range(8):
		var d:=legacy_displacement(ocean,g)
		g=point-Vector2(d.x,d.z)*(1.0-ocean.contact_at(g))
	return lerpf(legacy_displacement(ocean,g).y,ocean.plane_at(point.x,point.y),ocean.contact_at(g))
func _init(): call_deferred("run")
func run():
	var ocean:=CountedOcean.new(); root.add_child(ocean)
	check(ocean.create(preload("res://presentation/asset_catalog.gd").new()),"ocean loads")
	for bounds in [Vector4(0,0,2.35,2.1),Vector4(3,-2,7,5),Vector4(-5,4,1.2,1.05)]:
		ocean.raft_bounds=bounds
		for time in [0.0,.7,3.3,11.2]:
			ocean.tick(time)
			var center:=Vector2(bounds.x,bounds.y)
			for point in [center,center+Vector2(bounds.z,bounds.w),center+Vector2(bounds.z+float(ocean.settings.contact_margin),0),center+Vector2(bounds.z+float(ocean.settings.contact_margin)+.01,0),Vector2(7,2),Vector2(-9,4.5),Vector2(40,0)]:
				var reference:=legacy_height(ocean,point)
				var actual:=ocean.height_at(point.x,point.y)
				check(absf(reference-actual)<.000001,"legacy height parity %s t=%s" % [point,time])
				check(legacy_displacement(ocean,point).is_equal_approx(ocean.displacement(point)),"legacy displacement parity %s t=%s" % [point,time])
			ocean.displacements=0
			check(is_equal_approx(ocean.height_at(center.x,center.y),ocean.plane_at(center.x,center.y)),"full contact returns tangent plane")
			check(ocean.displacements==0,"full contact skips all inverse wave samples")
			ocean.noise_samples=0
			check(ocean.displacement(Vector2(40,0))==Vector3.ZERO,"outside fade is exactly flat")
			check(ocean.noise_samples==0,"zero amplitude skips wave noise")
	ocean.queue_free(); await process_frame
	print("OCEAN SAMPLING PERFORMANCE: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
