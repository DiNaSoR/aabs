"use strict";
var MainPanel = $("#MainBox")
var SelectedHeroData = null
var SelectedHeroPanel = null
var SelectedTabIndex = null
var HeroesPanels = []
var PlayerTables = GameUI.CustomUIConfig().PlayerTables
var DOTA_ACTIVE_GAMEMODE_TYPE = null;

function OpenMenu(data) {
	MainPanel.visible = true
	SelectHeroTab(1)
	SelectFirstHeroPanel()
}

function CreateMenu(data) {
	for (var tabKey in data.HeroTabs) {
		var tabTitle = data.HeroTabs[tabKey].title
		var heroesInTab = data.HeroTabs[tabKey].Heroes
		var TabHeroesPanel = $.CreatePanel('Panel', $("#HeroListPanel"), "HeroListPanel_tabPanels_" + tabKey)
		TabHeroesPanel.BLoadLayoutSnippet("HeroesPanel")
		FillHeroesTable(heroesInTab, TabHeroesPanel)
		TabHeroesPanel.visible = false
	}
	SelectHeroTab(1);
	SelectFirstHeroPanel();
}

function SwitchTab() {
	if (SelectedTabIndex == 1)
		SelectHeroTab(2)
	else
		SelectHeroTab(1)
}

function SelectHeroTab(tabIndex) {
	if (SelectedTabIndex != tabIndex) {
		if (SelectedTabIndex != null) {
			$("#HeroListPanel_tabPanels_" + SelectedTabIndex).visible = false
				//$("#HeroListTabsPanel_tabButtons_" + SelectedTabIndex).RemoveClass("HeroTabButtonSelected")
		}
		$("#HeroListPanel_tabPanels_" + tabIndex).visible = true
			//$("#HeroListTabsPanel_tabButtons_" + tabIndex).AddClass("HeroTabButtonSelected")
		SelectedTabIndex = tabIndex
	}
}

function ChooseHeroPanelHero() {
	ChooseHeroUpdatePanels()
}

function SelectHero() {
	GameEvents.SendCustomGameEventToServer("metamorphosis_elixir_cast", {
		hero: SelectedHeroData.heroKey
	})
	CloseMenu()
	Game.EmitSound("HeroPicker.Selected")
}

function UpdateSelectionButton() {
	if (SelectedHeroData != null && !IsHeroPicked(SelectedHeroData.heroKey)) {
		$("#SelectedHeroSelectButton").enabled = true
	} else {
		$("#SelectedHeroSelectButton").enabled = false
	}
}

function CloseMenu() {
	MainPanel.visible = false
}

function UpdateHeroList() {
	var hero_selection_available_heroes = PlayerTables.GetAllTableValues("hero_selection_available_heroes")
	if (hero_selection_available_heroes != null) {
		CreateMenu(hero_selection_available_heroes)
	} else {
		$.Schedule(0.03, UpdateHeroList)
	}
}

function UpdateHeroesSelected(tableName, changesObject, deletionsObject) {
	for (var k in HeroesPanels) {
		var heroPanel = HeroesPanels[k]
		if (heroPanel != null) {
			heroPanel.SetHasClass("HeroListElementPickedBySomeone", IsHeroPicked(heroPanel.id.substring("HeroListPanel_element_".length)))
		}
	}
	UpdateSelectionButton()
}

(function() {
	GameEvents.Subscribe("metamorphosis_elixir_show_menu", OpenMenu)
	MainPanel.visible = false
	PlayerTables.SubscribeNetTableListener("hero_selection", UpdateHeroesSelected)
	UpdateHeroesSelected("hero_selection", PlayerTables.GetAllTableValues("hero_selection"))
	UpdateHeroList()
	DynamicSubscribePTListener("arena", function(tableName, changesObject, deletionsObject) {
		if (changesObject["gamemode_settings"] != null && changesObject["gamemode_settings"]["gamemode_type"] != null)
			$("#SwitchTabButton").visible = changesObject["gamemode_settings"]["gamemode_type"] != DOTA_GAMEMODE_TYPE_RANDOM_OMG && changesObject["gamemode_settings"]["gamemode_type"] != DOTA_GAMEMODE_TYPE_ABILITY_SHOP
	})
	var f = function() {
		SearchHero()
		$.Schedule(0.2, f)
	}
	f();
})()