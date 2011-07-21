require 'ray'
require 'ray'

def path_of(res)
  File.expand_path File.join(File.dirname(__FILE__), res)
end

class CollectibleGem
  include Ray::Helper

  def initialize(pos)
    @sprite = Ray::Sprite.new path_of("CptnRuby Gem.png"), :at => pos
    @sprite.origin = @sprite.image.size / 2

    @animation = rotation(:from => -30, :to => 30, :duration => 0.6)
    @reverse_animation = -@animation
  end

  def register(scene)
    self.event_runner = scene.event_runner
    @animation.event_runner = @reverse_animation.event_runner = event_runner

    on :animation_end, @animation do
      @reverse_animation.start @sprite
    end

    on :animation_end, @reverse_animation do
      @animation.start @sprite
    end

    @animation.start @sprite
  end

  def update
    @animation.update
    @reverse_animation.update
  end

  attr_reader :sprite
end

class Map
  Tileset  = path_of("CptnRuby Tileset.png")
  PartSize = 60
  TileSize = 50

  def initialize(file)
    @tiles = {}
    @gems  = []

    File.foreach(file).with_index do |line, y|
      @max_y = y

      line.each_char.with_index do |char, x|
        @max_x = x

        case char
        when ?"
          @tiles[[x, y]] = Ray::Sprite.new(Tileset, :at => [x * TileSize - 5,
                                                            y * TileSize - 5])
          @tiles[[x, y]].sub_rect = [0, 0, PartSize, PartSize]
        when ?#
          @tiles[[x, y]] = Ray::Sprite.new(Tileset, :at => [x * TileSize - 5,
                                                            y * TileSize - 5])
          @tiles[[x, y]].sub_rect = [PartSize, 0, PartSize, PartSize]
        when ?x
          @gems << CollectibleGem.new([x * TileSize + TileSize / 2,
                                       y * TileSize + TileSize / 2])
        end
      end
    end

    @max_x *= TileSize
    @max_y *= TileSize
  end

  def each_tile
    @tiles.each { |_, tile| yield tile }
  end

  def each_gem(&block)
    @gems.each(&block)
  end

  def remove_gems(&block)
    @gems.delete_if(&block)
  end

  def solid?(x, y)
    y < 0 || @tiles[[x.to_i / TileSize, y.to_i / TileSize]]
  end

  attr_reader :max_x, :max_y
end

Ray.game "RPG motion" do
  register { add_hook :quit, method(:exit!) }

  scene :game do
    @half_size = window.size / 2

    @sky  = sprite path_of("Space.png")

    @map  = Map.new path_of("Map.txt")

    @sprite = sprite path_of("sprite.png")
    @sprite.sheet_size = [4, 4]

    @camera = Ray::View.new @sprite.pos, window.size


    always do
      if animations.empty?
        if holding? :down
          animations << sprite_animation(:from => [0, 0], :to => [4, 0],
                                         :duration => 0.3).start(@sprite)
          animations << translation(:of => [0, 32], :duration => 0.3).start(@sprite)
        elsif holding? :left
          animations << sprite_animation(:from => [0, 1], :to => [4, 1],
                                         :duration => 0.3).start(@sprite)
          animations << translation(:of => [-32, 0], :duration => 0.3).start(@sprite)
        elsif holding? :right
          animations << sprite_animation(:from => [0, 2], :to => [4, 2],
                                         :duration => 0.3).start(@sprite)
          animations << translation(:of => [32, 0], :duration => 0.3).start(@sprite)
        elsif holding? :up
          animations << sprite_animation(:from => [0, 3], :to => [4, 3],
                                         :duration => 0.3).start(@sprite)
          animations << translation(:of => [0, -32], :duration => 0.3).start(@sprite)
        end
      end

      # Center camera
      camera_x = [[@sprite.x, @half_size.w].max, @map.max_x - @half_size.w].min
      camera_y = [[@sprite.y, @half_size.h].max, @map.max_y - @half_size.h].min

      @camera.center = [camera_x, camera_y]

      @map.remove_gems { |gem| @sprite.collide? gem.sprite }
    end

    render do |win|
      win.draw @sky

      win.with_view @camera do # Apply scrolling
        @map.each_tile { |tile| win.draw tile       }
        @map.each_gem  { |gem|  win.draw gem.sprite }

        win.draw @sprite
      end
    end
  end

  scenes << :game
end
