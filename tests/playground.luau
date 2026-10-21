-- Run with Studio execute_luau (Edit or Server). No player data is touched.
local P = require(game.ReplicatedStorage.Shared.Playground)
local Config = require(game.ReplicatedStorage.Shared.Config.Playground)
local C = require(game.ReplicatedStorage.Shared.Playground.Common)
local bosses = {SnackVolley=true, SunbedSlalom=true, TreadmillTakeover=true, LegDayLandgrab=true, CrownSneak=true, GravityGauntlet=true}
local function solve(s, g)
 if s.t < 0 then return end
 local name = s.name
 if name == "SnackVolley" then P.Input(s, "move", s.ball.x, .5)
 elseif name == "SunbedSlalom" then
  local target = .5
  for _, o in s.obstacles do
   if o.y > .50 and o.y < .87 and math.abs(o.x-target)<.2 then target=if o.x<.5 then .85 else .15 end
  end
  P.Input(s,"move",target,.5)
 elseif name == "TreadmillTakeover" then
  if s.belt==1 and s.coach>=g.commit then P.Input(s,"down",.5,.5);P.Input(s,"up",.5,.5) end
 elseif name == "CrownSneak" then
  P.Input(s,if s.t%g.sweep < g.sweep*g.watchAt-.1 then "down" else "up",.5,.5)
 elseif name == "GravityGauntlet" then
  local target=if s.seal%2==0 then 1 else -1
  if s.gravity~=target then P.Input(s,"down",.5,.5);P.Input(s,"up",.5,.5) end
 elseif name == "LegDayLandgrab" then
  local path={1,2,3,4,10,16,15,14,13,19,20,21,22,28,34,33,32,31,25,19,13,14,15,16,10,4,5,6,12,18,17,16}
  local cell=path[math.min(math.floor(s.t/.10)+1,#path)]
  local x,y=C.xy(cell,6)
  P.Input(s,if s.held then "move" else "down",x,y)
 else P.Auto(s,Config.Step) end
end
-- Fast drags interpolate crossed cells instead of silently dropping the gesture.
local trace=P.New("ShortcutChalk",1)
trace.t=0
local sx,sy=C.xy(31,6);P.Input(trace,"down",sx,sy)
local tx,ty=C.xy(1,6);P.Input(trace,"move",tx,ty)
assert(#trace.path==6 and trace.path[6]==1,"Fast route drag lost intermediate cells")
local results={}
for name,g in Config.Games do
 if name == "ReadRip" then continue end
 for _,seed in {1,17,504} do
  local s=P.New(name,seed)
  for _=1,math.ceil((g.duration+Config.Lead+1)/Config.Step) do
   solve(s,s.rules);P.Step(s,Config.Step)
   for _,node in P.Draw(s) do
    assert(node.x==node.x and node.y==node.y and node.w>0 and node.h>0,name..": invalid drawing")
   end
   if s.finished then break end
  end
  assert(s.won,name..": solution failed, seed "..seed)
  assert(s.t<=g.duration,name..": finished too late")
  local before=s.score
  P.Input(s,"down",1,1);P.Step(s,1)
  assert(s.score==before,name..": completed game mutated")
 end
 local idle=P.New(name,1)
 for _=1,math.ceil((g.duration+Config.Lead+1)/Config.Step) do P.Step(idle,Config.Step) end
 assert(idle.finished and not idle.won,name..": idle completion exploit")
 if bosses[name] then
  local auto=P.New(name,1)
  for _=1,math.ceil((g.duration+Config.Lead+1)/Config.Step) do P.Auto(auto,Config.Step);P.Step(auto,Config.Step) end
  assert(not auto.won,name..": boss has autoplay")
 end
 table.insert(results,name..": 3 solutions + idle + terminal state passed")
 task.wait()
end
return results
