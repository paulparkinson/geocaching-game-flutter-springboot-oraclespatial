package example.oracle.spatial.geojson;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

public class Geometry {
    @Getter
    @Setter
    private String type = "Point";
    @Getter @Setter private List<Double> coordinates;


}