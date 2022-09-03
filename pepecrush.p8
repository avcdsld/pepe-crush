pico-8 cartridge // http://www.pico-8.com
version 36
__lua__

-- tile stuff
tiles={}
tile_type_num=7
tile_width=8
tile_height=10
offset_y=-2
offset_x=-20

-- cursor stuff
cursor_x=1
cursor_y=1
cursor_select_x=-1
cursor_select_y=-1
cursor_blink=0
cursor_blink_frames=20

-- game stuff
match_count=3
game_state=0 -- 0:title, 1:game, 2:gameover

title_music=9
game_music=0
music(title_music)

function _init()
    for x=1,tile_height do
        tiles[x] = {}
        for y=1,tile_width do
            tiles[x][y] = -1
        end
    end

    tiles_initialized = false
    wait_frames_for_clearing = 0
    score = 0
    time_left = 60 * 30 -- 1 min
    wait_frames_for_pepe = 0
    wait_frames_for_angry_pepe = 0

    -- bomb
    wanted_new_bomb_tile_type = -1
    bomb_spr_offset = 16
    wait_frames_for_bomb = 6
end

function inform_invalid_move()
    sfx(23) -- Invalid move
    wait_frames_for_angry_pepe = 30
    wait_frames_for_pepe = 0
end

function move_cursor()
    if btnp(0) then
        if cursor_x > 1 then
            cursor_x -= 1
        else
            inform_invalid_move()
        end
    end
    if btnp(1) then
        if cursor_x < tile_width then
            cursor_x += 1
        else
            inform_invalid_move()
        end
    end
    if btnp(2) then
        if cursor_y > 1 then
            cursor_y -= 1
        else
            inform_invalid_move()
        end
    end
    if btnp(3) then
        if cursor_y < tile_height then
            cursor_y += 1
        else
            inform_invalid_move()
        end
    end
end

function move_cursor_selected()
    -- to revert position if we move too far away from selected tile
    local temp_x = cursor_x
    local temp_y = cursor_y
    move_cursor()
    if abs(cursor_select_x - cursor_x) + abs(cursor_select_y - cursor_y) > 1 then
        cursor_x = temp_x
        cursor_y = temp_y
        inform_invalid_move()
    end
end

function select_cursor()
    if btnp(4) or btnp(5) then
        if cursor_select_x == -1 then
            -- select this tile
            cursor_select_x = cursor_x
            cursor_select_y = cursor_y
            sfx(21) -- Object select
        else
            -- something was selected
            swap_tiles(cursor_select_x, cursor_select_y, cursor_x, cursor_y)

            if cursor_select_x == cursor_x and cursor_select_y == cursor_y then
                -- sfx(32) -- TODO: cancel select sound
            else
                sfx(24) -- Swap Position
            end

            -- reset selection
            cursor_select_x = -1
            cursor_select_y = -1
        end
    end
end

function draw_gameover()
    cls(8)
    print_center("you scored " .. score, 64, 30, 7)
    local judgement = "good effort!"
    if score > 250 then
        judgement = "wow! good job!!"
    elseif score > 200 then
        judgement = "great work!"
    elseif score > 150 then
        judgement = "nice!"
    end
    print_center(judgement, 64, 40, 7)
    print_center("press z to restart", 60, 100, 7)
end

function make_bomb(tile_type)
    local candidates_count = 0
    local candidates_x = {}
    local candidates_y = {}
    for y=1,tile_height do
        for x=1,tile_width do
            if tiles[y][x] == tile_type then
                candidates_count += 1
                candidates_x[candidates_count] = x
                candidates_y[candidates_count] = y
            end
        end
    end
    if candidates_count == 0 then
        wanted_new_bomb_tile_type = tile_type + bomb_spr_offset
    else
        local num = flr(rnd(candidates_count)) + 1
        tiles[candidates_y[num]][candidates_x[num]] = tile_type + bomb_spr_offset
    end
end

function destroy_by_bomb(tile_type)
    for y=1,tile_height do
        for x=1,tile_width do
            if get_tile_type(tiles[y][x]) == tile_type then
                tiles[y][x] = -1
            end
        end
    end
end

function get_tile_type(tile)
    if tile > tile_type_num then
        return tile - bomb_spr_offset
    end
    return tile
end

-- returns: cleared_count, tile_type, include_bomb
function clear_match()
    for y=1,tile_height do
        for x=1,tile_width do
            local tile_type = get_tile_type(tiles[y][x])

            -- horizontal
            local count = 0
            for x1=x,tile_width do
                if get_tile_type(tiles[y][x1]) == tile_type then
                    count += 1
                else
                    break
                end
            end
            if count >= match_count then
                local include_bomb = clear_horizontally(x,y,count)
                score += count*count
                return count, tile_type, include_bomb
            end

            -- vertical
            count = 0
            for y1=y,tile_height do
                if get_tile_type(tiles[y1][x]) == tile_type then
                    count += 1
                else
                    break
                end
            end
            if count >= match_count then
                local include_bomb = clear_vertically(x,y,count)
                score += count*count
                return count, tile_type, include_bomb
            end
        end
    end
    return 0, 0, false
end

function clear_horizontally(x,y,count)
    local include_bomb = false
    for i=0,count do
        if tiles[y][x+i] > tile_type_num then
            include_bomb = true
        end
        tiles[y][x+i] = -1
    end
    return include_bomb
end

function clear_vertically(x,y,count)
    local include_bomb = false
    for i=0,count do
        if y + i > tile_height then
            break
        end
        if tiles[y+i][x] > tile_type_num then
            include_bomb = true
        end
        tiles[y+i][x] = -1
    end
    return include_bomb
end

function exists_empty_tiles()
    for y=1,tile_height do
        for x=1,tile_width do
            if tiles[y][x] < 1 then
                return true
            end
        end
    end
    return false
end

function swap_tiles(x0, y0, x1, y1)
    t0 = tiles[y0][x0]
    t1 = tiles[y1][x1]
    tiles[y0][x0] = t1
    tiles[y1][x1] = t0
end

function move_down_tiles()
    for y=tile_height,2,-1 do
        for x=1,tile_width do
            if tiles[y][x] < 1 and tiles[y-1][x] > 0  then
                swap_tiles(x, y, x, y - 1)
                -- sfx(3) -- TODO: sound
                if tiles_initialized then
                    return
                end
            end
        end
    end
    -- sfx(32) -- TODO: sound
end

function fill_top_tiles()
    for x=1,tile_width do
        if tiles[1][x] < 1 then
            if wanted_new_bomb_tile_type > 0 then
                tiles[1][x] = wanted_new_bomb_tile_type
                wanted_new_bomb_tile_type = -1
            else
                tiles[1][x] = flr(rnd(tile_type_num)) + 1
            end
        end
    end
end

function update_title()
    if btnp(4) then
        game_state = 1
        music(-1, 300)
        music(game_music)
    end
end

function update_game()
    if not tiles_initialized then
        score = 0
        time_left = 60 * 30 -- 1 min
    end

    if exists_empty_tiles() then
        move_down_tiles()
        fill_top_tiles()
        return
    end

    if wait_frames_for_clearing > 0 then
        wait_frames_for_clearing -= 1
        return
    end

    local matched_count, matched_tile_type, include_bomb = clear_match()
    if matched_count > 0 then
        sfx(20) -- Line Clear
        time_left += 5 * 30
        wait_frames_for_clearing = 5
        if include_bomb then
            destroy_by_bomb(matched_tile_type)
        end
        if matched_count >= 4 then
            make_bomb(matched_tile_type)
        end
        return
    end

    if not tiles_initialized then
        tiles_initialized = true
    end

    if time_left <= 0 and game_state != 2 then
        game_state = 2
        music(-1, 300)
        sfx(22) -- Gameover -- TODO: Change the sound depending on the judgement?
    end

    if game_state == 2 then
        if btnp(4) or btnp(5) then
            _init()
            game_state = 1
            music(game_music)
        end
        return
    end

    -- selected cursor blink
    cursor_blink += 1
    if cursor_blink > cursor_blink_frames then
        cursor_blink = 0
    end

    -- cursor movement
    if cursor_select_x == -1 then
        move_cursor()
    else
        move_cursor_selected()
    end
    select_cursor()
end

function _update()
    if game_state == 0 then
        update_title()
    else
        update_game()
    end
end

function print_center(s,x,y,c)
    local tx = x - ((#s * 4)/2)
    print(s, tx, y, c)
end

function draw_title()
    print_center("pepe crush", 64, 40, 7)
    print_center("by 8bit-acid-lab, feat. @ayalan", 64, 50, 7)
    print_center("⬅️⬆️⬇️➡️ move  z:select/swap    ", 64, 80, 6)
    print_center("press z to start", 64, 90, 7)
end

function draw_tiles()
    if wait_frames_for_bomb > 0 then
        wait_frames_for_bomb -= 1
    else
        wait_frames_for_bomb = 6
    end

    center_x = 64 - (tile_width * 8) / 2 + offset_x
    center_y = 64 - (tile_height * 8) / 2 + offset_y
    for y=1,tile_height do
        for x=1,tile_width do
            xpos = center_x + (x - 1) * 8
            ypos = center_y + (y - 1) * 8
            local spr_num = tiles[y][x]

            -- for bomb blink
            if tiles[y][x] > tile_type_num then
                if wait_frames_for_bomb % 6 >= 3 then
                    spr_num -= bomb_spr_offset
                end
            end

            spr(spr_num, xpos, ypos)

            local cursor_color = 7
            if cursor_select_x != -1 then
                cursor_color = 14
            end
            if x == cursor_x and y == cursor_y then
                rect(xpos - 1, ypos - 1, xpos + 8, ypos + 8, cursor_color)
            end

            if x==cursor_select_x and y==cursor_select_y and cursor_blink > cursor_blink_frames/2 then
                rect(xpos, ypos, xpos + 7, ypos + 7, 7)
            end
        end
    end
    for y=0,tile_height+1 do
        xpos = center_x - 1 * 8
        ypos = center_y + (y - 1) * 8
        spr(33, xpos, ypos)
        xpos = center_x + tile_width * 8
        spr(33, xpos, ypos)
    end
    for x=1,tile_width do
        xpos = center_x + (x - 1) * 8
        ypos = center_y + tile_height * 8
        spr(33, xpos, ypos)
    end
end

function draw_score()
    if not tiles_initialized then
        return
    end
    local str = "" .. score
    print_center("score", offset_x + 128, offset_y + 25, 7)
    print_center(str, offset_x + 128, offset_y + 35, 7)
end

function draw_time_left()
    if not tiles_initialized then
        return
    end
    if time_left > 0 then
        time_left -= 1
    end
    local str = "" .. flr(time_left / 30)
    print_center("time", offset_x + 128, offset_y + 50, 7)
    print_center(str, offset_x + 128, offset_y + 60, 7)
    if not tiles_initialized then
        return
    end
end

function draw_pepe()
    local x = 94
    local y = 78

    if wait_frames_for_angry_pepe > 0 then
        wait_frames_for_angry_pepe -= 1
        local spr_num = 140 -- angry pepe
        local offset = 0
        if wait_frames_for_angry_pepe % 4 >= 2 then
            offset = 1
        end
        spr(spr_num, x + offset, y, 4, 4)
        return
    end

    if wait_frames_for_pepe > 0 then
        wait_frames_for_pepe -= 1
    else
        wait_frames_for_pepe = 150
    end

    local spr_num = 12 -- opened eyes
    if wait_frames_for_pepe < 4 then
        spr_num = 64 -- half opened eyes
    elseif wait_frames_for_pepe < 8 then
        spr_num = 68 -- closed eyes
    elseif wait_frames_for_pepe < 12 then
        spr_num = 64 -- half opened eyes
    elseif wait_frames_for_pepe < 16 then
        spr_num = 68 -- closed eyes
    elseif wait_frames_for_pepe < 20 then
        spr_num = 64 -- half opened eyes
    end
    spr(spr_num, x, y, 4, 4)
end

function draw_time_left_bar()
    if not tiles_initialized then
        return
    end
    local num = time_left / 30 / 5
    local str = ""
    for i=1,num do
        str = str .. "|"
    end
    print(str, offset_x + 25, offset_y + 118, 7)
end

function draw_game()
    draw_tiles()
    draw_score()
    draw_time_left()
    draw_pepe()
    draw_time_left_bar()
end

function _draw()
    cls(0)
    if game_state == 0 then
        draw_title()
    elseif game_state == 1 then
        draw_game()
    else
        draw_gameover()
    end
end

__gfx__
0000000001111110000000000060000000066000000040000000000000000900000000001d11111d1111000000000000000000001d11111d1111000000000000
000000001111111100004220067600000066d500000494000aa00aa00000982000000011dd1dd1dddddd11000000000000000011dd1dd1dddddd110000000000
000000001b311b31000425f26ccc600000787100000494000a09a09009988200000000dd1d1dd1dddddddd1000000000000000dd1d1dd1dddddddd1000000000
000000001077007700425f5f06c7cd000087c7000049a94000aa9900987820000000011111dddd111d111dd1000000000000011111dddd111d111dd100000000
000000001007b0070045f5f0006cd000007c7200047aaa9400075000888200000000111111111111111111d1100000000000111111111111111111d110000000
00000000bbbbbbbb042f5f00000d0d0000c787000477a9940070060002228000000111d1dddddddddd11111111000000000111d1dddddddddd11111111000000
00000000388888834220f000000000d00066d500004799400700006000002800000111dddd1d1d1dd1dd111111000000000111dddd1d1d1dd1dd111111000000
0000000003333330220000000000000d00055000000444000000000000000200001dd1d111111111111dddd111100000001dd1d111111111111dddd111100000
0000000007777770000000000070000000077000000070000000000000000700001ddd1111111111111111ddddd00000001ddd1111111111111111ddddd00000
000000007777777700007770077700000077770000077700077007700000777000dd111bbbbbbbbbbb31111dddd1000000dd111bbbb33b3bbb31111dddd10000
00000000777777770007777777777000007777000007770007077070077777000ddd11bbbbbbbbbbbbb1111ddddd00000ddd11bbbbb33bbbbbb1111ddddd0000
00000000707700770077777707777700007777000077777000777700777770000d111bb3773bbbb7733331111ddd10000d111bb333bb3bb3333331111ddd1000
000000007007700700777770007770000077770007777777000770007777000001111b3707bbbb3f073b3111dddd100001111b3707b3b33f073b3111dddd1000
000000007777777707777700000707000077770007777777007007000777700001d11b50073bbb5700fbb3111d1d100001d11b50073b3b5700fbb3111d1d1000
000000007777777777707000000000700077770000777770070000700000770001111b3ff3bbbbb3fff333111ddd100001111b3ff3bbbbb3fff333111ddd1000
000000000777777077000000000000070007700000077700000000000000070001111b3bbbbbbbbbb3bbb3111111100001111b3bbbbbbbbbb3bbb31111111000
00000000effffff7000000000000000000000000000000000000000000000000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000
000000002effff7f008808800000000000000000000000000000000000000000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000
0000000022eeeeff08f88882000000000000000000000000000000000000000000011bbbbbbbbbbbbbbb33111111000000011bbbbbbbbbbbbbbb331111110000
0000000022eeeeff08f888820000000000000000000000000000000000000000000113bbbb30023bbbbbb31111110000000113bbbb3333bbbbbbb31111110000
0000000022eeeeff08888882000000000000000000000000000000000000000000003bb32200002222bb33111110000000003bb32222222222bb331111100000
0000000022eeeeff008888200000000000000000000000000000000000000000000003bbb2000023bb3b311111100000000003bbb233b323bb3b311111100000
00000000221111ef000282000000000000000000000000000000000000000000000003bbbb32223bbbbb331111000000000003bbbb32233bbbbb331111000000
000000002111111e0000200000000000000000000000000000000000000000000000003bbbb333bbbbb33131100000000000003bbbb333bbbbb3313110000000
0000000000000000000000000000000000000000000000000000000000000000000000033bbbbbbbbb33131110000000000000033bbbbbbbbb33131110000000
0000000000000000000000000000000000000000000000000000000000000000000000003b3bb3b33333313100000000000000003b3bb3b33333313100000000
00000000000000000000000000000000000000000000000000000000000000000000000033b33333333b3310000000000000000033b33333333b331000000000
000000000000000000000000000000000000000000000000000000000000000000000000b131313131b3313eee00000000000000b131313131b3313eee000000
00000000000000000000000000000000000000000000000000000000000000000000000eb313131313b3331eeeee00000000000eb313131313b3331eeeee0000
0000000000000000000000000000000000000000000000000000000000000000000000ee3b3131313bbb313eeeeeee00000000ee3b3131313bbb313eeeeeee00
00000000000000000000000000000000000000000000000000000000000000000000eeeee3b33333b3b313eeeeeeeee00000eeeee3b33333b3b313eeeeeeeee0
000000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeee
000000001d11111d1111000000000000000000001d11111d1111000000000000000000001d11111d1111000000000000000000001d11111d1111000000000000
00000011dd1dd1dddddd11000000000000000011dd1dd1dddddd11000000000000000011dd1dd1dddddd11000000000000000011dd1dd1dddddd110000000000
000000dd1d1dd1dddddddd1000000000000000dd1d1dd1dddddddd1000000000000000dd1d1dd1dddddddd1000000000000000dd1d1dd1dddddddd1000000000
0000011111dddd111d111dd1000000000000011111dddd111d111dd1000000000000011111dddd111d111dd1000000000000011111dddd111d111dd100000000
0000111111111111111111d1100000000000111111111111111111d1100000000000111111111111111111d1100000000000111111111111111111d110000000
000111d1dddddddddd11111111000000000111d1dddddddddd11111111000000000111d1dddddddddd11111111000000000111d1dddddddddd11111111000000
000111dddd1d1d1dd1dd111111000000000111dddd1d1d1dd1dd111111000000000111dddd1d1d1dd1dd111111000000000111dddd1d1d1dd1dd111111000000
001dd1d111111111111dddd111100000001dd1d111111111111dddd111100000001dd1d111111111111dddd111100000001dd1d111111111111dddd111100000
001ddd1111111111111111ddddd00000001ddd1111111111111111ddddd00000001ddd1111111111111111ddddd00000001ddd1111111111111111ddddd00000
00dd111bbbb33b3bbb31111dddd1000000dd111bbbb33b3bbb31111dddd1000000dd111bbbb33b3bbb31111dddd1000000dd111bbbb33b3bbb31111dddd10000
0ddd11bbbbb33bbbbbb1111ddddd00000ddd11bbbbb33bbbbbb1111ddddd00000ddd11bbbbb33bbbbbb1111ddddd00000ddd11bbbbb33bbbbbb1111ddddd0000
0d111bb3333b3b33333331111ddd10000d111bb3333b3b33333331111ddd10000d111bb333bb3bb3333331111ddd10000d111bb333bb3bb3333331111ddd1000
01111b3bb333b33bb33b3111dddd100001111b333333b333bb3b3111dddd100001111b3777b3b337773b3111dddd100001111b3777b3b337773b3111dddd1000
01d11b50073b3b5700fbb3111d1d100001d11b3bbb3b3b3bbbb3b3111d1d100001d11b57603b3b57707bb3111d1d100001d11b50673b3b50077bb3111d1d1000
01111b3ff3bbbbb3fff333111ddd100001111b3333bbbbb3333333111ddd100001111b3f03bbbbb3700333111ddd100001111b3003bbbbb3077333111ddd1000
01111b3bbbbbbbbbb3bbb3111111100001111b3bbbbbbbbbb3bbb3111111100001111b3bbbbbbbbbb3bbb3111111100001111b3bbbbbbbbbb3bbb31111111000
001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000
001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000001113bbbbbbbbbbbbbbbb11d1111000
00011bbbbbbbbbbbbbbb33111111000000011bbbbbbbbbbbbbbb33111111000000011bbbbbbbbbbbbbbb33111111000000011bbbbbbbbbbbbbbb331111110000
000113bbbb3333bbbbbbb31111110000000113bbbb3333bbbbbbb31111110000000113bbbb3333bbbbbbb31111110000000113bbbb3333bbbbbbb31111110000
00003bb32222222222bb33111110000000003bb32222222222bb33111110000000003bb32222222222bb33111110000000003bb32222222222bb331111100000
000003bbb233b323bb3b311111100000000003bbb233b323bb3b311111100000000003bbb233b323bb3b311111100000000003bbb233b323bb3b311111100000
000003bbbb32233bbbbb331111000000000003bbbb32233bbbbb331111000000000003bbbb32233bbbbb331111000000000003bbbb32233bbbbb331111000000
0000003bbbb333bbbbb33131100000000000003bbbb333bbbbb33131100000000000003bbbb333bbbbb33131100000000000003bbbb333bbbbb3313110000000
000000033bbbbbbbbb33131110000000000000033bbbbbbbbb33131110000000000000033bbbbbbbbb33131110000000000000033bbbbbbbbb33131110000000
000000003b3bb3b33333313100000000000000003b3bb3b33333313100000000000000003b3bb3b33333313100000000000000003b3bb3b33333313100000000
0000000033b33333333b3310000000000000000033b33333333b3310000000000000000033b33333333b3310000000000000000033b33333333b331000000000
00000000b131313131b3313eee00000000000000b131313131b3313eee00000000000000b131313131b3313eee00000000000000b131313131b3313eee000000
0000000eb313131313b3331eeeee00000000000eb313131313b3331eeeee00000000000eb313131313b3331eeeee00000000000eb313131313b3331eeeee0000
000000ee3b3131313bbb313eeeeeee00000000ee3b3131313bbb313eeeeeee00000000ee3b3131313bbb313eeeeeee00000000ee3b3131313bbb313eeeeeee00
0000eeeee3b33333b3b313eeeeeeeee00000eeeee3b33333b3b313eeeeeeeee00000eeeee3b33333b3b313eeeeeeeee00000eeeee3b33333b3b313eeeeeeeee0
00eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeee
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d11111d1111000000000000
00777780077000700077770007777770077000700077777007777770077777000777770007777770000000000000000000000011dd1dd1dddddd110000000000
077000000777077007700070000770000770008007700070000770000770007007700070077000000000000000000000000000dd1d1dd1dddddddd1000000000
0077770007707070077000700007700007700070077000700007700008700070077000700777780000000000000000000000011111dddd111d111dd100000000
0000007007700070077000700007700007777770077777700007700007777700077877000770000000000000000000000000111111111111111111d110000000
077000700770007007700080000770000770007007700070000770000770007007700000077000000000000000000000000111d1dddddddddd11111111000000
007777000770008000777700000870000770007007700080088777700770007007700000077777700000000000000000000111dddd1d1d1dd1dd111111000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001dd1d111111111111dddd111100000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ddd1111111111111111ddddd00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dd111bbb33333bbbb1111dddd10000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ddd11b33bbb3bbb33b1111ddddd0000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d111b3773b33b33707331111ddd1000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011117707733333f77773111dddd1000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d113777733333bbbbb33111d1d1000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111b33333333b3333333111ddd1000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111bbbbbb33bbbb3bbb31111111000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001113bbbbbbbbbbbbbbbb11d1111000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001113b22222222222bbbb31d1111000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011bb200000000002bbb3111110000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088883b088888000000bbb3111110000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008822888882228800000bbb3111100000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200222202002222200bbb3111100000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003bbbb32233333bbb33111000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003bbbb33333bbbb313110000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033bbbbbbbbb33131110000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003b3bb3b33333313100000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033b33333333b331000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b131313131b3313eee000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eb313131313b3331eeeee0000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ee3b3131313bbb313eeeeeee00
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eeeee3b33333b3b313eeeeeeeee0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeee
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007000000000000070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007010504050105070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007030405010306070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007060504030104070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007040301050103070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007060106040305070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007010506040406070000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000007070707070707070000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccfeccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccf7decccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cf7fedeccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cedef7fccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cced7fccccccccccccccccccccccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccefccccccccccccccccccccccccccccc7777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333333333333333333333bb777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3333333333333333333333333333333b7777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3bb33b333bb33b333bb33b33333333337777777777777cccccccccccccccccc6cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3bb333333bb333333bb3333333bb3333777777777777777ccccccccccccccc66dccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333333333333333333bb333377777777777777777cccccccccccc66dddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333333333333333333333333777777777777777777cccccccccc666dddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333333333333333333333337777777777777777777cccccccc6666ddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333b333333333333333b3337777777777777777777ccccccc6666ddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333bab33339a3333333bab377777777777777777777ccccc66d6ddddddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333bbb33339a7a33333bbb33777777777777777777777ccc66d66ddddddddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3333333333333b333399a93333333b33777777777777777777777cc66666ddddddddddddccccccccccccccc6ccccccccccccccccccccccccccccccc6cccccccc
333333333b333333333993333b3333337777777777777777777777666666dddddddddddddccccccccccccc66dcccccccccc7777ccccccccccccccc66dccccccc
33333333333333333333333333333333777777777777777777777766666dddddddddddddddccccccccccc66dddcccccccc7777777ccccccccccccc66ddcccccc
33333333333333333333333333333333777777777777777777776666666dddddddddddddddcccccccccc666dddccccccc777777777cccccccccc6666ddcccccc
33333333333333333333333333333333777777777777777777766666666ddddddddddddddddcccccccc6666ddddcccc777777777777cccccccc66666dddcccc7
33333333333333333333b33333333333777777777777777777666d6666ddddddddddddddddddcccccc6666ddddddcc7777777777777ccccccc666d66ddddcc77
33333333333333333333bab33333333377777777777777777666d6666ddddddddddddddddddddcccc66d6ddddddddc77777777777777ccccc666d666dddddc77
3333333333333333333bbb333333333377777777777777776d6666666ddddddddddddddddddddddc66d66dddddddddd77777777777777ccc6d666666ddddddd7
333333333333333333333b33333333337777777777777776666666666666dddddddddddddddddddd6666dddddddddddd7777777777777cc666666666dddddddd
33333333333333333b33333333333333d777777777777766666666666666ddddddddddddddddddddd666ddddddddddddd77777777777776666666666dddddddd
33333333333333333333333333333333dd7777777777776666666666666ddddddddddddddddddddddd6d66dddddddddddd7777777777766dd66666dddddddddd
33333333333333333333333333333333dd7777777777666666666666666ddddddddddddddddddddddd66666ddddddddddd7777777777666ddd6666dddddddddd
33333333333333333333333333333333ddd777777776666666666666666dddddddddddddddddddddddd666ddddddddddddd777777776666ddddd6ddddddddddd
3333b333333333333333b33333333333dddd777777666d666666666666ddddddddddddddddddddddddd6dddddddddddddddd7777776666dddddddddddddddddd
3333bab3333333333333bab33339a333ddddd7777666d666666666666dddddddddddddddddddddddddddddddddddddddddddd777766d6ddddddddddddddddddd
333bbb3333333333333bbb33339a7a33ddddddd76d666666666666666dddddddddddddddddddddddddddddddddddddddddddddd766d66ddddddddddddddddddd
33333b333333333333333b333399a933dddddddd6666666666666666dddddddddddddddddddddddddddddddddddddddddddddddd66666666dddddddddddddddd
3b333333333333333b33333333399333dddddddd6666666666666666dddddddddddddddddddddddddddddddddddddddddddddddd66666666dddddddddddddddd
33333333333333333333333333333333ddddddddd66666ddd66666ddddddddddddddddddddddddddddddddddddddddddddddddddd66666dddddddddddddddddd
33333333333333333333333333333333dddddddddd6666dddd6666dddddddddddddddddddddddddddddddddddddddddddddddddddd6666dddddddddddddddddd
33333333333333333333333333333333dddddddddddd6ddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddd
3333333333333333333333333333b333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
3333333333333333333333333333bab3dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
333333333333333333333333333bbb33dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333b33dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
3333333333333333333333333b333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33133133331331333313313333133133dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
31311313313113133131131331311313dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
13111131131111311311113113111131dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
1d1d12224444d4d4ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777dddddddd
111d12224444d444dddddddddddddddddddddddddfdddfdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
d1dd1124444424dddddbdddddddddddddddddddddffffffddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
d1111222444424dddddbdddddd7d7ddddddddddddf1fff1ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
dddd12224444ddddbddbdddddddedddddddddddddeffffedddddddddddddddddddddddddddddddddddddddddddddddddddd7dddddddddddd2eeeeeefdddddddd
dddd112444444ddddbdbddbddd737ddddddddddddd222ddddddddddddddddddddddddddddddddddddddddddddddddddddd7a7ddddddddddd2eeeeeefdddddddd
ddd12222244444dddbdbdbdddddbdddddddddddddd888dddddddddddddddddddddddddddddddddddddddddddddddddddddd7dddddddddddd2eeeeeefdddddddd
dd1111122444444ddbdbdbdddddbddddddddddddddfdfdddddddddddddddddddddddddddddddddddddddddddddddddddddd3dddddddddddd2222222ddddddddd
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333222333332223333322233333222333332223333322233333222333332223333322233333222333332223333322233333222333332223333322233333222
23332222233322222333222223332222233322222333222223332222233322222333222223332222233322222333222223332222233322222333222223332222
22224442222244422222444222224442222244422222444222224442222244422222444222224442222244422222444222224442222244422222444222224442
22244444222444442224444422244444222444442224444422244444222444442224444422244444222444442224444422244444222444442224444422244444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
22442244444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444464444444444444
44224424444444444444444444444444444444444444224444444444444444444444444444444444444444444444444444444444444444444666d44444444444
2442244444444444444444444444444444444444422442244444444444444444444444444444444444444444444444444444444444444444422d666444444444
22442244444444444444444444444444444444444422444444444444444444444444444444444444444444444444444444444444444444444442262444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444444224444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444446644442244224444444444224422442244224422442244444444444444444444444444224422442244224444444444444444444444444444444444
4444444442d674444224422444444444422442244224422442244224444444444444444444444444422442244224422444422444444444444444444444444444
4444444422dd66444422442444444444442244244422442444224424444444444444444444444444442244244422442444442244444444444444444444444444
4444444422ddd6642442244444444444244224442442244424422444444444444444444444444444244224442442244442244224444444444444444444444444
4444444422dddd642244224444444444224422442244224422442244444444444444444444444444224422442244224444224444444444444444444444444444
44444444222222444224422444444444422442244224422442244224444444444444444444444444422442244224422444422444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
110100202171021710217202173021740217502176021770217702176021750217402173021720217102171021710217102172021730217402175021760217702177021760217502174021730217202171021710
001100201c7141c7111c7211c7311c7411c7511c7611c7711c7711c7611c7511c7411c7311c7211c7111c7151c7141c7101c7201c7301c7401c7501c7601c7701c7701c7601c7501c7401c7301c7201c7101c710
010100201c7101c7101c7201c7301c7401c7501c7601c7701c7701c7601c7501c7401c7301c7201c7101c7101c7101c7101c7201c7301c7401c7501c7601c7701c7701c7601c7501c7401c7301c7201c7101c710
011000201f0301f010210302101023030230101a0301a0101f0301f010210302101023030230101a0301a0102103021010230302301024030240101a0301a0102103021010230302301024030240101a0301a010
011000202b0261c0262b0261c026180262402618026240260000000000000000000000000000000000000000214261c226214261c226184262422618426242260000000000000000000000000000000000000000
a10100201a7101a7101a7201a7301a7401a7501a7601a7701a7701a7601a7501a7401a7301a7201a7101a7101a7101a7101a7201a7301a7401a7501a7601a7701a7701a7601a7501a7401a7301a7201a7101a710
110100201f7101f7101f7201f7301f7401f7501f7601f7701f7701f7601f7501f7401f7301f7201f7101f7101f7101f7101f7201f7301f7401f7501f7601f7701f7701f7601f7501f7401f7301f7201f7101f710
011000002603026010240302401023030230101f0301f0102603026010240302401023030230101f0301f01028030280102403024010230302301021030210102403024010230302301021030210101f0301f010
3d1000002603026010240302401023030230101f0301f0102603026010240302401023030230101f0301f01028030280102403024010230302301021030210102403024010230302301021030210101f0301f010
151000003271032710327203273032740327503276032770327703276032750327403273032720327103271032710327103272032730327403275032760327703277032760327503274032730327203271032710
011000000c0730000024600000000c0730000000000000000c0730000018100000000c0730000000000000000c0730000000000000000c0730000000000000000c0730000000000000000c073000000000000000
011000000c043000000000000000000000000000000000000c043000000000000000000000000000000000000c043000000000000000000000000000000000000c0430000000000000000c043000000000000000
011000201f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f713
010f002000000000003f215000000c61500000000000000000000000003f215000000c6153f6153f1123f21100000000003f215000000c61500000000000000000000000003f215000000c6153f6153f1123f211
011000201811300000000000000018113000000000000000181130000000000000001811300000000000000018113000000000000000181130000000000000001811300000000000000018113000000000000000
01100020071200711013130071201311007120071201f11009120091102111015120091201511009120091101a110021200e1100e120021200e110021201a11000120001200c1100c120001200c1100012000110
011000202172521725217242171321735217452174421713217252172521724217132173521745217442171321725217252172421713217352174521744217132172521725217242171321735217452174421713
011000201c7251c7251c7241c7131c7351c7451c7441c7131c7251c7251c7241c7131c7351c7451c7441c7131c7251c7251c7241c7131c7351c7451c7441c7131c7251c7251c7241c7131c7351c7451c7441c713
011000201f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f7131f7251f7251f7241f7131f7351f7451f7441f713
011000001a7251a7251a7241a7131a7351a7451a7441a7131a7251a7251a7241a7131a7351a7451a7441a7131a7251a7251a7241a7131a7351a7451a7441a7131a7251a7251a7241a7131a7351a7451a7441a713
01040000244401f44024440284402b440304402b440304402b4403044034440374403c44037440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0104000024142131422414200000241001f20024300284002b500306002b70000000241001f20024300284002b500304002b40000000244001f40024400284002b400304002b4000000000000000000000000000
01100000244421f442244421c4421f442244411f441244411c4411f44118441134411844110441134410c441134410c4411044113441134311342113411134110000000000000000000000000000000000000000
01100000184471f447000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000241451f145241451f14500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00000c0730000024600000000c0730000000000000000c0730000018100000000c0730000000000000000c0730000000000000000c0730000000000000000c0730000000000000000c073000000000000000
010a00002b0261c0262b0261c026180262402618026240260000000000000000000000000000000000000000214261c226214261c226184262422618426242260000000000000000000000000000000000000000
010a00001f0301f010210302101023030230101a0301a0101f0301f010210302101023030230101a0301a0102103021010230302301024030240101a0301a0102103021010230302301024030240101a0301a010
010a00001f7101f7101f7201f7301f7401f7501f7601f7701f7701f7601f7501f7401f7301f7201f7101f7101f7101f7101f7201f7301f7401f7501f7601f7701f7701f7601f7501f7401f7301f7201f7101f710
010a00002171021710217202173021740217502176021770217702176021750217402173021720217102171021710217102172021730217402175021760217702177021760217502174021730217202171021710
010a00002603026010240302401023030230101f0301f0102603026010240302401023030230101f0301f01028030280102403024010230302301021030210102403024010230302301021030210101f0301f010
010a00001c7101c7101c7201c7301c7401c7501c7601c7701c7701c7601c7501c7401c7301c7201c7101c7101c7101c7101c7201c7301c7401c7501c7601c7701c7701c7601c7501c7401c7301c7201c7101c710
010a00001a7101a7101a7201a7301a7401a7501a7601a7701a7701a7601a7501a7401a7301a7201a7101a7101a7101a7101a7201a7301a7401a7501a7601a7701a7701a7601a7501a7401a7301a7201a7101a710
010700000c4151f4150c4151c415134152441513415184151f415244151c4152b415244152b415281152b115244151f41524415284152b415304152b415304152b4153041534415374153c415374153411537115
000100082b0261c0262b0261c02618026240261802624026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
110700000c4111f4110c4111c411134112441113411184111f411244111c4112b411244112b411281112b111244111f41124411284112b411304112b411304112b4113041134411374113c411374113411137111
010800000c0740000024600000000c0740000000000000000c0740000018100000000c0740000000000000000c0740000000000000000c0740000000000000000c0740000000000000000c074000000000000000
015000000004300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 06030a04
00 00070a04
00 02030a04
00 05030a04
00 060a0704
00 000a0304
00 05000b04
02 050a0304
00 41474344
01 0c0d0e0f
00 100d0e0f
00 110d0e0f
02 130d0e0f
00 41424344
00 14424344
01 191a1b1c
00 191a1d1e
00 191a1b1f
02 191a1b20
00 21242344
00 14424344
00 15424344
00 16424344
00 18424344
00 25424344

