-- Studio Client test; no profile changes. Restores the rig afterward.
local player=game.Players.LocalPlayer
local client=player.PlayerScripts.Client
local Rig=require(client.Activities.Rig)
local Activity=require(client.Activities.Playground)
local Rules=require(game.ReplicatedStorage.Shared.Playground)
local Config=require(game.ReplicatedStorage.Shared.Config.Playground)
local character=player.Character
local rig=Rig.new(character)
assert(rig)
local count=0
local ok,err=pcall(function()
 for name in Config.Games do
  if name=="ReadRip" then continue end
  local activity=Activity.new({rig=rig,measures=rig:Measure(character.Humanoid),top=rig.root.CFrame*CFrame.new(0,-3,0),minigame=name,isLocal=false})
  local passed,message=pcall(function()
   for _,held in {false,true} do
    local state=Rules.New(name,17)
    state.t,state.held,state.x,state.y,state.pulse=1,held,.7,.3,1
    activity:SetState(state);rig:Clear();activity:Pose(0,0,0,1);rig:Apply()
   end
  end)
  activity:Destroy()
  assert(passed,name..": "..tostring(message))
  count+=1
  task.wait()
 end
end)
rig:Release()
assert(ok,tostring(err))
return {animated=count}
