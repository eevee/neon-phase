local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local DialogueScene = require 'klinklang.scenes.dialogue'


local MEMO_KEY_SCRIPTS = {
    junkyard = {
        { "Another uneventful day...", speaker = 'memo' },
        { "No, wait, I did catch a glimpse of a surveilleon. I hope no one thinks I'm goofing off...  I don't know why else they'd be spying on me like that. I didn't do anything wrong, did I?", speaker = 'memo' },
        { "wrong, did I?", speaker = 'memo' },
        { "Oh, I just saw a flicker. I keep seeing it. It's driving me mad. Is something wrong with my eyes? I want to ask if someone else can see it, or if it's just me... ", speaker = 'memo' },
        { "I haven't seen any other workers in weeks, though, so that'll have to wait.", speaker = 'memo' },
        { "Back to work.", speaker = 'memo' },
        { "Hm. Wonder how long ago this was written.", speaker = 'kidneon' },
        { "(This memo seems to also contain some kind of key data.)", speaker = 'kidneon' },
    },
    belowtal = {

        { "First the flicker, now this. I keep hearing some kind of commotion coming from inside the heart of the Yard. When I really strain to listen, there's a shout or a cry or something. Then static. Then nothing. ", speaker = 'memo' },
        { "I should go check on everyone, but... well, I left my keys around, so I can't get inside anyway. ", speaker = 'memo' },
        { "Why bother, honestly. It's not my business.", speaker = 'memo' },
        { "I need to stop typing. I think I'm getting a migraine.", speaker = 'memo' },
        { "Hey, Chip. Do you hear anything out of the ordinary around here?", speaker = 'kidneon' },
        { "BZZT... PARAMETERS TOO BROAD FOR TESLIC YARD. NOTHING IS ORDINARY HERE. ", speaker = 'chip' },
        { "Then list everything you hear.", speaker = 'kidneon' },
        { "IT WOULD TAKE HALF AN HOUR.", speaker = 'chip' },
        { "...oh. Then nevermind. Upload the plain text file for me to look over later.", speaker = 'kidneon' },
        { "I ALREADY HAVE.", speaker = 'chip' },
        { "(This memo seems to also contain some kind of key data.)", speaker = 'kidneon' },
    },
    anise = {
        {
            "Ha ha. Guess what?",
            "I really thought -- for just a split second -- that someone was actually going to update me on the situation. But no, I'm just an idiot.",
            "I turned around, and no one was there. I don't know what tapped my shoulder.",
            "I probably just hallucinated it.",
            "Tired.",
            speaker = 'memo',
        },
        {
            "Physical hallucinations in Teslic Yard... seemingly common without an electronull suit. Wish I had more time to study the effects of this place on different bodies. Seems like an interesting area of research.",
            "...",
            "Wonder if I could get Charthur or Jasmaby to come here.",
            speaker = 'kidneon',
        },
        { "UNLIKELY. BZZT.", speaker = 'chip' },
        { "Yeah. You're right.", "I'd need a bribe.", speaker = 'kidneon' },
        { "(This memo seems to also contain some kind of key data.)", speaker = 'kidneon' },
    },
    emptyhouse = {
        {
            "I can't sleep. Again. Again, again, again. The smell's overwhelming.",
            "Normally there'd be someone fixing the leak, right? Where the hell are they? Where the hell is anyone?",
            "If they don't fix it soon, I'm just not coming back down here. I can't. I'll just sleep at my post.",
            "Or, I don't know. Maybe I just won't come back at all. I'm so tired of this.",
            "I don't even care what happened.",
            "No one needs me here anymore, anyway.",
            speaker = 'memo',
        },
        { "Lucky this helmet's got air purifiers built in. Good thinking, me.", speaker = 'kidneon' },
        { "THAT WAS MY SUGGESTION.", speaker = 'chip' },
        {
            "That I listened to, in an act of good thinking.",
            "...",
            "Thanks, Chip.",
            speaker = 'kidneon',
        },
        { "(This memo seems to also contain some kind of key data.)", speaker = 'kidneon' },
    },
    purrl = {
        {
            "Springs, cogs, bolts, screws... I just wanted to enjoy a nice meal. That's it.",
            "I tried to eat, I really did, but the spill just wrecks my appetite. No one's come to fix it. No one.",
            "So I thought, maybe I'd try to fix it myself. I thought, maybe they're watching me to see what I'll do by myself.",
            "Maybe that's why no one's here. Cause it's a test.",
            "I thought, maybe they're seeing if I'll sit around and complain, or if I'll go address the problem.",
            "Well, joke's on me!",
            "I started making my way down, but that smell just messed me up too badly to keep going. A second later, I collapsed on the slope.",
            "And now, here I am, stuck in a loop of feeling bad and hating myself over how useless I am, all because I actually tried for once. Cool.",
            speaker = 'memo',
        },
        { "The spill's completely solidified. Chip, do you know what materials comprise this spill? And do you have any idea how long it takes to harden?", speaker = 'kidneon' },
        {
            "DOUBLE AFFIRMATIVE. BZZT... CALCULATING...",
            "COMPLETE SOLIDIFICATION ESTIMATED TO TAKE AT LEAST HALF A MILLENNIUM.",
            speaker = 'chip',
        },
        {
            "Oh. Uh. Huh.",
            "...",
            "Wonder if it's edible.",
            speaker = 'kidneon',
        },
        { "(This memo seems to also contain some kind of key data.)", speaker = 'kidneon' },
    },
    graveyard = {
        {
            "Today, I found out why no one's been going in or out of Teslic Yard.",
            "Haha. I suspected it a while ago.",
            "It all happened overnight.",
            "Or maybe it's been there for a while. I don't know. Could've just been ignoring it.",
            "I don't like graveyards.",
            "I looked around, anyway. I needed some kind of closure before moving on.",
            "Each terminal had a lot of information about a particular individual.",
            "Some kind of memorial, I guess? It's just creepy though.",
            "All these coworkers... reduced to a list of names, a list of facts.",
            "I didn't cry or anything.",
            "Haha, how did I miss it? Something's really wrong with this place.",
            "Something's really wrong with my head.",
            "I'll sleep.",
            "I slept for the first time in a long while aftrhgbdshgvbvhsdjg",
            "fffffffffdsggggggggggggggg",
            "nice dream",
            speaker = 'memo',
        },
        { "...", speaker = 'kidneon' },
        { "(This memo has no key data on it. No need to take it.)", speaker = 'kidneon' },
    },
}


local MemoKey = actors_base.Actor:extend{
    name = 'memo key',
    sprite_name = 'memo key',
}

function MemoKey:init(pos, props)
    MemoKey.__super.init(self, pos)
    self.script_name = props['script name']
    if not MEMO_KEY_SCRIPTS[self.script_name] then
        error(("No such memo key script %s"):format(self.script_name))
    end
end

function MemoKey:blocks()
    return false
end

function MemoKey:on_collide(other, direction)
    if other.is_player then
        if self.script_name ~= 'graveyard' then
            game.progress.keys = (game.progress.keys or 0) + 1
        end
        worldscene:remove_actor(self)
        Gamestate.push(DialogueScene({
            -- Speakers
            memo = {
                color = {255, 191, 81},
            },
            kidneon = other,
            chip = other.ptrs.chip,
        }, MEMO_KEY_SCRIPTS[self.script_name]))
    end
end


return MemoKey
