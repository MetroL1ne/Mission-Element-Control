 AdminMissionElementsList = AdminMissionElementsList or {}

function AdminMissionElementsList:init()
	Input:keyboard():add_trigger(Idstring("f10"), callback(self, self, "setup"))  --Toggle Keybind
	Input:keyboard():add_trigger(Idstring("esc"), callback(self, self, "hide"))  --Hide Keybind
end

function AdminMissionElementsList:setup()
	self._mission_element_h = 30
	self._main_layer = 500
	self._ui = {}
	self._saved_search = nil
	self._on_mouse_panel = {}
	self._info_class = {}

	self:switch()
end

function AdminMissionElementsList:switch()
	if self._selected then
		return
	end

	if self._enabled then
		self:hide()
	else
		self:show()
	end
end

function AdminMissionElementsList:show()
	self._ws = managers.gui_data:create_fullscreen_workspace({})

	self:show_mission_elements()

	-- set controller
	if game_state_machine then
		game_state_machine:current_state():set_controller_enabled(not managers.player:player_unit())  --锁定玩家视角
	end

	self._mouse_id = self._mouse_id or managers.mouse_pointer:get_id()
	self._mouse_data = {
		mouse_move = callback(self, self, "mouse_moved"),
		mouse_press = callback(self, self, "mouse_pressed"),
		mouse_release = callback(self, self, "mouse_released"),
		mouse_click = callback(self, self, "mouse_clicked"),
		id = self._mouse_id,
		menu_ui_object = self
	}
	managers.mouse_pointer:use_mouse(self._mouse_data)

	local controller = managers.controller:get_controller_by_name("MenuManager")
	
	if controller then
		controller:set_enabled(false)
	end

	if managers.menu and managers.menu.active_menu and managers.menu:active_menu() and managers.menu:active_menu().input then
		managers.menu:active_menu().input:set_back_enabled(false)
		managers.menu:active_menu().input:accept_input(false)
	end

	self._enabled = true
end

function AdminMissionElementsList:hide()
	if not self._enabled then
		return
	end

	if self._ws then
		self._ws:hide()
		managers.gui_data:destroy_workspace(self._ws)
		self._ws = nil
	end

	managers.mouse_pointer:remove_mouse(self._mouse_data)

	if game_state_machine then
		game_state_machine:current_state():set_controller_enabled(true)  --恢复玩家视角
	end

	local controller = managers.controller:get_controller_by_name("MenuManager")
	
	if controller then
		controller:set_enabled(true)
	end

	if managers.menu and managers.menu.active_menu and managers.menu:active_menu() and managers.menu:active_menu().input then
		managers.menu:active_menu().input:set_back_enabled(true)
		managers.menu:active_menu().input:accept_input(true)
	end

	self._saved_search = nil
	self._on_mouse_panel = {}

	self._enabled = false
end

function AdminMissionElementsList:mouse_moved(o, x, y)
	if self._selected then
		return
	end

	if game_state_machine then
		game_state_machine:current_state():set_controller_enabled(not managers.player:player_unit())  --锁定玩家视角
	end

	self._mouse_inside = false
	self._elements_scroll:mouse_moved(o, x, y)

	for _, cls in pairs(self._info_class) do
		self._mouse_inside = cls:mouse_moved(o, x, y) and true or self._mouse_inside
	end

	---[[ Mission Elements List Mouse Moved
	if self._elements_scroll._scroll._grabbed_scroll_bar then
		-- 计算当前滚动比例 (0 到 1)
		local scroll_ratio = (self._elements_scroll._scroll._scroll_bar:y() - 16) / (self._elements_scroll:h() - 58)

		-- 计算内容面板的最大滚动距离
		local max_content_scroll = (self._mission_element_h * #self._elements_scroll:items()) - self._elements_scroll:h()

		-- 计算内容面板的目标位置（负数，因为内容面板是向下移动的）
		local target_content_y = -scroll_ratio * max_content_scroll
		local current_content_y = self._elements_scroll:items()[1]:top()

		-- 计算需要滚动的偏移量（当前内容面板的 y 与目标位置的差值）
		local dy = target_content_y - current_content_y

		-- 调用 wheel_scroll 进行滚动
		self:wheel_scroll(self._elements_scroll:items(), self._mission_element_h, self._elements_scroll:h(), dy)
	end

	self._touch_element_item = nil
	if self._scroll_panel:inside(x, y) then  --如果鼠标在列表内
		local item = self:get_panel_under_mouse(x, y)  -- 检测有没有鼠标有没有在其中一个item之上

		if item then
			self._mouse_inside = true
			self._touch_element_item = item
		end
	end

	if self._elements_scroll._scroll._scroll_bar:inside(x, y) or self._elements_scroll._scroll._grabbed_scroll_bar then
		self._mouse_inside = true
	end

	if self._touch_element_item then
		if self._on_mouse_panel[1] ~= self._touch_element_item then
			table.insert(self._on_mouse_panel, 1, self._touch_element_item)
			table.remove(self._on_mouse_panel, 3)

			for k, item in ipairs(self._on_mouse_panel) do
				if item and item:child("bg") then
					if k == 1 then
						item:child("bg"):set_visible(true)
					else
						item:child("bg"):set_visible(false)
					end
				end
			end
		end
	else
		for k, item in ipairs(self._on_mouse_panel) do
			if alive(item) then
				item:child("bg"):set_visible(false)
			end
		end

		self._on_mouse_panel = {}
	end


	local inside = alive(self._mission_element_searchbox.panel) and self._mission_element_searchbox.panel:inside(x, y) or false

	if inside and not self._mission_element_searchbox._focus then
		self._mouse_inside = true
	end
	-- Mission Elements List Mouse Moved ]]

	if self._mouse_inside then
		managers.mouse_pointer:set_pointer_image("link")
	else
		managers.mouse_pointer:set_pointer_image("arrow")
	end
end

function AdminMissionElementsList:mouse_pressed(o, button, x, y)
	if self._selected then
		return
	end

	if button == Idstring("mouse wheel up") then
		return self:mouse_wheel_up(x, y)
	elseif button == Idstring("mouse wheel down") then
		return self:mouse_wheel_down(x, y)
	end

	if button == Idstring("0") then
		if self._touch_element_item then
			self:set_element_info(self._touch_element_item)
		end
	end

	self._elements_scroll:mouse_pressed(button, x, y)
	self._mission_element_searchbox:mouse_pressed(button, x, y)

	for _, cls in pairs(self._info_class) do
		cls:mouse_pressed(button, x, y)
	end
end

function AdminMissionElementsList:mouse_released(o, button, x, y)
	if self._selected then
		return
	end

	return self._elements_scroll:mouse_released(button, x, y)
end

function AdminMissionElementsList:mouse_clicked(o, button, x, y)
	if self._selected then
		return
	end

	return self._elements_scroll:mouse_clicked(o, button, x, y)
end

function AdminMissionElementsList:mouse_wheel_up(x, y)
	self:wheel_scroll(self._elements_scroll:items(), self._mission_element_h, self._elements_scroll:h(), 60)
	self._elements_scroll:perform_scroll(60)

	return self._elements_scroll:mouse_wheel_up(x, y)
end

function AdminMissionElementsList:mouse_wheel_down(x, y)
	self:wheel_scroll(self._elements_scroll:items(), self._mission_element_h, self._elements_scroll:h(), -60)
	self._elements_scroll:perform_scroll(-60)

	return self._elements_scroll:mouse_wheel_down(x, y)
end

function AdminMissionElementsList:wheel_scroll(items, h, panel_h, dy)
	local panels = items

	if h * #panels >= panel_h then
		if dy > 0 then
			dy = panels[1]:top() + dy >= 0 and -panels[1]:top() or dy
		else
			if panels[#panels]:bottom() + dy <= panel_h then
				dy = panel_h - panels[#panels]:bottom()
			end
		end

		for _, panel in ipairs(panels) do
			panel:set_y(panel:top() + dy)
		end
	end
end

--获得当前鼠标下的element的panel（性能优化，避免遍历全部）
function AdminMissionElementsList:get_panel_under_mouse(x, y)
	if self._elements_scroll:items()[1] then
		local top = self._elements_scroll:items()[1]:top()
		local bottom = self._elements_scroll:items()[1]:bottom()
		local in_vis_top = (bottom <= 0) and math.round(-top / self._mission_element_h) or 0

		for key, panel in ipairs(self._elements_scroll:items()) do   
			if self._elements_scroll:items()[key + in_vis_top] and self._elements_scroll:items()[key + in_vis_top]:inside(x, y) then
				return self._elements_scroll:items()[key + in_vis_top]
			end
		end
	end
end

function AdminMissionElementsList:show_mission_elements()
	self._ui.mission_element = self._ws:panel():panel({
		layer = self._main_layer,
		w = 300,
		h = 600
	})

	self._ui.mission_element:set_center_y(self._ws:panel():center_y())
	self._ui.mission_element:set_left(self._ws:panel():left()+100)

	self._scroll_panel = self._ui.mission_element:panel({
		w = self._ui.mission_element:w(),
		h = self._ui.mission_element:h() - 50
	})

	-- Mission Elements Scroll Bar
	self._elements_scroll = ScrollItemList:new(self._scroll_panel, {
		scrollbar_padding = 0,
		bar_minimum_size = 16,
		padding = 0,
		w = self._scroll_panel:w(),
		h = self._scroll_panel:h(),
		input_focus = true
	}, {
		padding = 0
	})

	---[[ Element Info Panel 元素信息面板
	self._ui.info = self._ws:panel():panel({
		visible = false,
		layer = self._main_layer,
		w = 600,
		h = self._elements_scroll:canvas():h()
	})

	self._ui.info:set_left(self._ui.mission_element:right())
	self._ui.info:set_top(self._ui.mission_element:top())

	BoxGuiObject:_create_side(self._ui.info, "left", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "right", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "top", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "bottom", 1, false, false)
	--Element Info Panel 元素信息面板 ]]

	self._ui.title = self._ws:panel():panel({
		visible = false,
		layer = self._main_layer,
		w = self._ui.info:w(),
		h = 50
	})

	self._ui.title:set_left(self._ui.info:left())
	self._ui.title:set_bottom(self._ui.info:top())

	local title_text = self._ui.title:text({
		name = "text",
		color = Color.white,
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = "Unknown",
		font_size = 30
	})

	title_text:set_bottom(self._ui.title:bottom())

	self._elements_scroll:add_lines_and_static_down_indicator()
	for name, data in pairs(managers.mission:scripts()) do
		for id, element in pairs(data:elements()) do
			local item = self._elements_scroll:add_item(self:set_element_panel(self._scroll_panel, {
				element = element,
				h = self._mission_element_h
			}))
		end
	end

	if SearchBoxGuiObject and managers.menu:is_pc_controller() then
		self._mission_element_searchbox = SearchBoxGuiObject:new(self._ui.mission_element, self._ws, self._saved_search)
		self._mission_element_searchbox.panel:set_center_x((self._scroll_panel:w() - 20) / 2)
		self._mission_element_searchbox.panel:set_top(self._scroll_panel:bottom())
		self._mission_element_searchbox:register_callback(callback(self, self, "update_items_list", false))
	end
end

function AdminMissionElementsList:set_element_panel(panel, data)
	if not data.element then
		error("Cannot Find Element")
	end

	local element_panel = panel:panel({
		name = tostring(data.element:id()),
		w = panel:w() - 20,
		h = data.h or panel:h()
	})

	-- element_panel:set_top(id_max * (element_panel:h() + 0.8))
	self._bg = element_panel:rect({
		name = "bg",
		visible = false,
		color = Color.black,
		layer = -1,
		alpha = 0.7,
		w = element_panel:w(),
		h = element_panel:h()
	})

	local element_box_panel = element_panel:panel({
		name = "element_box_panel",
		w = panel:w() - panel:w() / 3,
		h = element_panel:h()
	})

	element_panel:set_left(element_panel:left())

	local element_name_text = element_box_panel:text({
		name = "element_name_text",
		vertical = "center",
		valign = "center",
		align = "center",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = data.element:editor_name(),
		font_size = 18
	})

	local center_x = element_box_panel:w() / 2
	local center_y = element_box_panel:h() / 2

	element_name_text:set_center_y(center_y)
	element_name_text:set_center_x(element_box_panel:center_x())

	-- Element id Text
	local element_id_text = element_panel:text({
		name = "element_id_text",
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = tostring(data.element:id()),
		font_size = 18
	})

	element_id_text:set_left(element_box_panel:right())

	return element_panel
end

function AdminMissionElementsList:update_items_list(scroll_position, search_list, search_text)
	if search_text then
		search_text = search_text:lower()
	end

	self._saved_search = search_text and search_text:lower() or nil

	for _, panel in ipairs(self._elements_scroll:items()) do
		self._scroll_panel:remove(panel)
	end

	self._elements_scroll:clear()

	for _, data in pairs(managers.mission:scripts()) do
		for _, element in pairs(data:elements()) do
			if string.is_nil_or_empty(search_text) or string.find(string.lower(element:editor_name()), search_text, nil, true) or 
				string.is_nil_or_empty(search_text) or string.find(tostring(element:id()), search_text, nil, true)
			then
				self._elements_scroll:add_item(self:set_element_panel(self._scroll_panel,{
					element = element,
					h = self._mission_element_h
				}))
			end
		end
	end
end

function AdminMissionElementsList:set_element_info(item)
	local item = item or self._touch_element_item

	if not item then
		return
	end

	for _, cls in pairs(self._info_class) do
		self._ui.info:remove(cls:panel())
	end

	local element = managers.mission:get_element_by_id(tonumber(item:name()))
	self._ui.info:set_visible(true)
	self._ui.title:set_visible(true)
	self._ui.title:child("text"):set_text(element:editor_name() .. " : " .. tostring(element:id()))
			
	self._info_class.enabled = AdminToggleButton:new(self._ui.info, {
		visible = true,
		text = "Enabled",
		state = element._values.enabled,
		w = 200,
		h = 30
	})

	self._info_class.enabled:panel():set_top(2)
	self._info_class.enabled:panel():set_left(2)

	self._info_class.enabled:set_callback(function()
		local state = not element._values.enabled
		element._values.enabled = state

		self:send_log(element:editor_name(), element:id(), element._values.enabled)
	end)
end

function AdminMissionElementsList:send_log(...)
	local message = ""

	for _, v in ipairs({...}) do
		if message == "" then
			message = message .. tostring(v)
		else
			message = message .. " " .. tostring(v)
		end
	end

	managers.mission._fading_debug_output:script().log(tostring(message), color)
end

if GameSetup then
	Hooks:PostHook(GameSetup, "init_managers", "AdminMissionElementsList-GameSetup:init_managers", function(self, t, dt)
		 AdminMissionElementsList:init()
	end)
end

AdminToggleButton = AdminToggleButton or class()

function AdminToggleButton:init(panel, data)
	self._parent = panel
	self._state = data.state or false

	self._panel = panel:panel({
		name = data.name or nil,
		visible = tostring(data.visible) == "false" and false or true,
		w = data.w or 0,
		h = data.h or 0,
		layer = data.layer
	})

	local rect = self._panel:rect({
		name = "rect",
		visible = false,
		w = self._panel:w(),
		h = self._panel:h(),
		layer = -1,
		color = Color.black,
		alpha = 0.7
	})

	local tickbox_toggle = self._panel:bitmap({
		name = "tickbox_toggle",
		color = data.box_color or Color.white,
		texture = "guis/textures/menu_tickbox",
		texture_rect = {
			self._state and 24 or 0,
			0,
			24,
			24
		},
		w = data.box_size,
		h = data.box_size
	})

	tickbox_toggle:set_right(self._panel:right())
	tickbox_toggle:set_center_y(self._panel:h() / 2)

	local tickbox_text = self._panel:text({
		name = "tickbox_text",
		color = data.text_color or Color.white,
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = data.text,
		font_size = data.font_size and size.font_size or 20
	})

	tickbox_text:set_left(self._panel:left())
	tickbox_text:set_center_y(self._panel:h() / 2)
end

function AdminToggleButton:panel()
	return self._panel
end

function AdminToggleButton:parent()
	return self._parent
end

function AdminToggleButton:callback()
	return self._callback
end

function AdminToggleButton:set_callback(clbk)
	self._callback = clbk
end

function AdminToggleButton:mouse_moved(o, x, y)
	local mouse_inside = false

	if self:inside(x, y) then
		self._panel:child("rect"):set_visible(true)
		mouse_inside = true
	else
		self._panel:child("rect"):set_visible(false)
	end

	return mouse_inside
end

function AdminToggleButton:mouse_pressed(button, x, y)
	if button == Idstring("0") then
		if self:inside(x, y) then
			if self:callback() then
				self:callback()()
			end

			return self:toggle()
		end
	end
end

function AdminToggleButton:inside(x, y)
	if self._panel:inside(x, y) then
		return true, "link"
	end

	return false, "arrow"
end

function AdminToggleButton:toggle()
	local new_state = not self._state
	self:set_state(new_state)

	return new_state
end

function AdminToggleButton:set_state(state)
	self._state = state
	local box = self._panel:child("tickbox_toggle")

	box:set_texture_rect(
		state and 24 or 0,
		0,
		24,
		24
	)
end