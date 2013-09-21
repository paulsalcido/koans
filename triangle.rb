# Triangle Project Code.

# Triangle analyzes the lengths of the sides of a triangle
# (represented by a, b and c) and returns the type of triangle.
#
# It returns:
#   :equilateral  if all sides are equal
#   :isosceles    if exactly 2 sides are equal
#   :scalene      if no sides are equal
#
# The tests for this method can be found in
#   about_triangle_project.rb
# and
#   about_triangle_project_2.rb
#
#
# All of these subs with the same method structure just
# scream 'extract class', don't they?
def triangle(a, b, c)
  if triangle_has_errors(a, b, c) then
    raise TriangleError
  end
  if a == b and b == c then
    :equilateral
  elsif a == b or b == c or a == c then
    :isosceles
  else
    :scalene
  end
end

def triangle_has_negatives_or_zeros(a, b, c)
  [a, b, c].reject { |x| x > 0 }.length > 0
end

def triangle_has_a_long_side(a, b, c)
  [a, b, c].permutation.to_a.reject { |x| x[0] + x[1] > x[2] }.length > 0
end

def triangle_has_errors(a, b, c)
  triangle_has_negatives_or_zeros(a, b, c) or triangle_has_a_long_side(a, b, c)
end

# Error class used in part 2.  No need to change this code.
class TriangleError < StandardError
end
